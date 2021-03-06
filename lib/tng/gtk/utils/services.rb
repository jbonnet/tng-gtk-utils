## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
require 'sinatra'
require 'json'
require 'securerandom'
require 'net/http'
require 'ostruct'
require 'json'
require 'tng/gtk/utils/application_controller'
require 'tng/gtk/utils/logger'
require 'tng/gtk/utils/fetch'

class FetchNSDService < Tng::Gtk::Utils::Fetch
  NO_CATALOGUE_URL_DEFINED_ERROR='The CATALOGUE_URL ENV variable needs to defined and pointing to the Catalogue where to fetch services'
  LOGGED_COMPONENT=self.name
  LOGGER=Tng::Gtk::Utils::Logger
  
  CATALOGUE_URL = ENV.fetch('CATALOGUE_URL', '')
  if CATALOGUE_URL == ''
    LOGGER.error(component:LOGGED_COMPONENT, operation:'fetching CATALOGUE_URL ENV variable', message:NO_CATALOGUE_URL_DEFINED_ERROR)
    raise ArgumentError.new(NO_CATALOGUE_URL_DEFINED_ERROR) 
  end
  self.site=CATALOGUE_URL+'/network-services'
end

class ServicesController < Tng::Gtk::Utils::ApplicationController

  ERROR_SERVICE_NOT_FOUND="No service with UUID '%s' was found"
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  
  get '/?' do 
    msg='#get (many)'
    captures=params.delete('captures') if params.key? 'captures'
    result = FetchNSDService.call(symbolized_hash(params))
    if result.to_s.empty? # covers nil
      halt 404, {}, {error: "No packages fiting the provided parameters ('#{params}') were found"}.to_json
    end
    halt 200, {}, result.to_json
  end
  
  get '/:uuid/?' do 
    msg='#get (single)'
    captures=params.delete('captures') if params.key? 'captures'
    result = FetchNSDService.call(symbolized_hash(params))
    if result.to_s.empty? # covers nil
      halt 404, {}, {error: ERROR_SERVICE_NOT_FOUND % params[:uuid]}.to_json
    end
    halt 200, {}, result.to_json
  end
  
  options '/?' do
    msg='#options'
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,DELETE'      
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
    halt 200
  end
  
  private
  def uuid_valid?(uuid)
    return true if (uuid =~ /[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}/) == 0
    false
  end
  
  def symbolized_hash(hash)
    Hash[hash.map{|(k,v)| [k.to_sym,v]}]
  end
end

