#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

# adds a "require_relative" function to the Ruby Kernel if it
# doesn't already exist (used to deal with the fact that
# "require" is used instead of "require_relative" prior
# to Ruby v1.9.2)
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require 'rubygems'
require 'logger'
require 'net/http'
require 'cgi'
require 'json'
require 'webrick'
require_relative 'rz_mk_configuration_manager'

include WEBrick

# get a reference to the Configuration Manager instance (a singleton)
config_manager = RzMkConfigurationManager.instance

# setup a logger for our HTTP server...
logger = Logger.new('/var/log/rz_mk_web_server.log', 5, 1024*1024)
logger.level = config_manager.default_mk_log_level
logger.formatter = proc do |severity, datetime, progname, msg|
  "(#{severity}) [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}]: #{msg}\n"
end

# next, define our actions (as servlets)...for now we have one (used to
# save the Microkernel Configuration that is received from the MCollective
# Configuration Agent)

class MKConfigServlet < HTTPServlet::AbstractServlet

  def initialize(server, logger)
    super(server)
    @logger = logger
    # get a reference to the Configuration Manager instance (a singleton)
    @config_manager = RzMkConfigurationManager.instance
  end

  def do_POST(req, res)
    # get a reference to the Configuration Manager instance (a singleton)
    config_manager = RzMkConfigurationManager.instance
    # get the Razor URI from the request body; it should be included in
    # the body in the form of a string that looks something like the following:
    #
    #     "razorURI=<razor_uri_val>"
    #
    # where the razor_uri_val is a CGI-escaped version of the URI used by the
    # Razor server.  The "Registration Path" (from the uri_map, above) is added
    # to this Razor URI value in order to form the "registration_uri"
    json_string = CGI.unescape(req.body)
    @logger.debug("in POST; configuration received...#{json_string}")
    # Note: have to truncate the CGI escaped body to get rid of the trailing '='
    # character (have no idea where this comes from, but it's part of the body in
    # a "post_form" request)
    config_map = JSON.parse(json_string[0..-2])
    # create a new HTTP Response
    config = WEBrick::Config::HTTP
    resp = WEBrick::HTTPResponse.new(config)
    # check to see if the configuration has changed
    if @config_manager.mk_config_has_changed?(config_map, @logger)
      # if the configuration has changed, then save the new configuration and restart the
      # Microkernel Controller (forces it to pick up the new configuration)
      @config_manager.save_mk_config(config_map, @logger)
      @logger.level = @config_manager.mk_log_level
      @logger.debug("Config changed, restart the controller...")
      %x[sudo /usr/local/bin/rz_mk_controller.rb restart]
      return_msg = 'New configuration saved, Microkernel Controller restarted'
      resp['Content-Type'] = 'text/plain'
      resp['message'] = return_msg
      @logger.debug("#{return_msg}...")
    else
      # otherwise, just log the fact that the configuration has not changed in the response
      resp['Content-Type'] = 'json/application'
      return_msg = 'Configuration unchanged; no update'
      resp['message'] = JSON.generate({'json_received' => config_map,
                                       'message' => return_msg })
      @logger.debug("#{return_msg}...")
    end
  end

end

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2156, :ServerType => WEBrick::Daemon)

# mount our servlets as directories under our HTTP server's URI

s.mount("/setMkConfig", MKConfigServlet, logger)

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start out server

s.start
