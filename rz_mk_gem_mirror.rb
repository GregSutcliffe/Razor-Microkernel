#!/usr/bin/env ruby

# this is rz_mk_control_server.rb
# it starts up a WEBrick server that can be used to control the Microkernel
# (commands to the Microkernel are invoked using Servlets running in the
# WEBrick instance)
#
#

require 'rubygems'
require 'yaml'
require 'net/http'
require 'cgi'
require 'json'
require 'webrick'
require 'webrick/httpstatus'
require 'razor_microkernel/logging'

# include the WEBrick mixin (makes this into a WEBrick server instance)
include WEBrick

# next, define our actions (as servlets)...

# set up a global variable that will be used in the RazorMicrokernel::Logging mixin
# to determine where to place the log messages from this script
RZ_MK_LOG_PATH = "/var/log/rz_mk_gem_mirror.log"

# include the RazorMicrokernel::Logging mixin (which enables logging)
include RazorMicrokernel::Logging

# Now, create an HTTP Server instance (and Daemonize it)

s = HTTPServer.new(:Port => 2158, :Logger => logger, :ServerType => WEBrick::Daemon)

# mount our servlets as directories under our HTTP server's URI

s.mount("/gems", HTTPServlet::FileHandler, "/tmp/gem-mirror")

# setup the server to shut down if the process is shut down

trap("INT"){ s.shutdown }

# and start our server

s.start
