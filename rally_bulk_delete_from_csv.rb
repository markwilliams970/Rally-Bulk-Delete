# Copyright 2002-2013 Rally Software Development Corp. All Rights Reserved.
#
# This script is open source and is provided on an as-is basis. Rally provides
# no official support for nor guarantee of the functionality, usability, or
# effectiveness of this code, nor its suitability for any application that
# an end-user might have in mind. Use at your own risk: user assumes any and
# all risk associated with use and implementation of this script in his or
# her own environment.

# Usage: ruby rally_bulk_delete_from_csv.rb
# Specify the User-Defined variables below. Script will find and prompt user
# to confirm deletion of all Rally Artifacts within a specified range of FormattedID's

require 'csv'
require 'rally_api'

$my_base_url        = "https://rally1.rallydev.com/slm"
$my_username        = "user@company.com"
$my_password        = "password"
$my_workspace       = "My Workspace"
$my_project         = "My Project"
$project_scope_down = true
$wsapi_version      = "1.43"
$filename           = "items_to_delete.csv"

# Do not make changes to code below this line!!!
################################################

# Load (and maybe override with) my personal/private variables from a file...
my_vars= File.dirname(__FILE__) + "/my_vars.rb"
if FileTest.exist?( my_vars ) then require my_vars end

def delete_rally_artifact(header, row)

  affirmative_answer = "y"

  item_formatted_id               = row[header[0]].strip
  item_name                       = row[header[1]].strip
  upcase_formatted_id             = item_formatted_id.upcase

  artifact_prefix = upcase_formatted_id[/[A-Z]+/]
  artifact_type   = $valid_query_types[artifact_prefix]

  if artifact_type.nil? then
    puts "Invalid artifact type specified in Formatted ID."
    puts "Valid Formatted ID Prefix types include:"
    puts "#{$valid_types}."
    puts "Skipping #{item_formatted_id}"
    return
  end

  # Query Rally for item to delete
  # Lookup test case to move
  query = RallyAPI::RallyQuery.new()
  query.type = artifact_type
  query.fetch = "FormattedID,ObjectID,Name"
  query.query_string = "(FormattedID = \"" + item_formatted_id + "\")"

  query_results = @rally.find(query)

  if query_results.total_result_count == 0
    puts "Artifact #{item_formatted_id} not found...skipping"
  else
    item_to_delete = query_results.first
    puts "Deleting Item #{item_formatted_id}: #{item_name}..."
    begin
      really_delete = [(print "Really delete? [N/y]:"), gets.rstrip][1]
      if really_delete.downcase == affirmative_answer then
        delete_result = @rally.delete(item_to_delete["_ref"])
        puts "DELETED #{item_formatted_id}: #{item_name}"
        @delete_count += 1
      else
        puts "Did NOT delete #{item_formatted_id}: #{item_name}."
      end
    rescue => ex
      puts "Error occurred trying to delete: #{item_formatted_id}: #{item_name}"
      puts ex
      puts ex.backtrace
    end
  end
end

begin
  puts "Connecting to Rally: #{$my_base_url} as #{$my_username}..."
  #==================== Make a connection to Rally ====================

  #Setting custom headers
  $headers                            = RallyAPI::CustomHttpHeader.new()
  $headers.name                       = "Ruby Rally Artifact Bulk Delete From CSV Utility"
  $headers.vendor                     = "Rally Labs"
  $headers.version                    = "0.50"
  $my_headers                         = $headers

  config                  = {:base_url => $my_base_url}
  config[:username]       = $my_username
  config[:password]       = $my_password
  config[:workspace]      = $my_workspace
  config[:project]        = $my_project
  config[:version]        = $wsapi_version
  config[:headers]        = $my_headers #from RallyAPI::CustomHttpHeader.new()

  # Valid Artifact Types. Note that the following assumes
  # Standard PI Types of Theme, Feature, and Initiative.
  # If user has custom PI Types, the following list will need to be
  # Customized to user environment
  $standard_types = ["US", "DE", "TA", "TC"]
  $pi_types = ["T", "I", "F"]

  $valid_types = [$standard_types, $pi_types].flatten

  $valid_query_types = {
    "US" => :hierarchicalrequirement,
    "DE" => :defect,
    "TA" => :task,
    "TC" => :testcase,
    "F"  => "portfolioitem/feature",
    "I"  => "portfolioitem/initiative",
    "T"  => "portfolioitem/theme"
  }

  @rally = RallyAPI::RallyRestJson.new(config)

  # Read in CSV worksheet of items that need deleting
  input  = CSV.read($filename)

  header = input.first #ignores first line

  rows   = []
  (1...input.size).each { |i| rows << CSV::Row.new(header, input[i]) }

  number_processed = 0

  # Proceed through rows in input CSV and delete  items contained therein
  puts "Deleting selected entries from Rally..."

  @delete_count = 0
  rows.each do |row|
    delete_rally_artifact(header, row)
    number_processed += 1
  end

  puts
  puts "Deleted a total of #{@delete_count} Artifacts."
  puts "Complete!"
end