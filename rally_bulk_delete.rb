# Copyright 2002-2013 Rally Software Development Corp. All Rights Reserved.
#
# This script is open source and is provided on an as-is basis. Rally provides
# no official support for nor guarantee of the functionality, usability, or
# effectiveness of this code, nor its suitability for any application that
# an end-user might have in mind. Use at your own risk: user assumes any and
# all risk associated with use and implementation of this script in his or
# her own environment.

# Usage: ruby rally_bulk_delete.rb
# Specify the User-Defined variables below. Script will find and prompt user
# to confirm deletion of all Rally Artifacts within a specified range of FormattedID's

require 'rally_api'

$my_base_url        = "https://rally1.rallydev.com/slm"
$my_username        = "user@company.com"
$my_password        = "password"
$my_workspace       = "My Workspace"
$my_project         = "My Project"
$project_scope_down = true
$wsapi_version      = "1.40"

# Do not make changes to code below this line!!!
################################################

# Load (and maybe override with) my personal/private variables from a file...
my_vars= File.dirname(__FILE__) + "/my_vars.rb"
if FileTest.exist?( my_vars ) then require my_vars end

puts "This script can be used to delete all Rally artifacts within a specified Formatted ID Range."
puts "Located in Workspace: #{$my_workspace} and Project: #{$my_project}."
puts "Valid Artifact Types include any item that can be identified by a Formatted ID: "
puts "User Stories (US), Defects (DE), Tasks (TA), Test Cases (TC), and Portfolio Items (T, I, F)"
puts "User will be prompted to confirm each Artifact for deletion."

# Ask user for Formatted ID Range
puts "Please enter Starting and Ending Formatted ID's for Deletion Range."
puts "Note that the Range is INCLUSIVE. The Artifacts corresponding to the start and end"
puts "of the Range will be included in deletion attempt."
puts
start_formatted_id = [(print 'Enter Starting Formatted ID of Deletion Range: '), gets.rstrip][1].upcase
end_formatted_id = [(print 'Enter Ending Formatted ID of Deletion Range: '), gets.rstrip][1].upcase

# Perform error checking
start_artifact_type = start_formatted_id[/[A-Z]+/]
start_number_range = start_formatted_id[/\d+/]

if start_artifact_type.nil? or start_number_range.nil? then
  puts "Invalid starting FormattedID. Please use the format DE1234. Exiting."
  exit
end

end_artifact_type = end_formatted_id[/[A-Z]+/]
end_number_range = end_formatted_id[/\d+/]

if end_artifact_type.nil? or end_number_range.nil? then
  puts "Invalid ending FormattedID. Please use the format DE1234. Exiting."
  exit
end

start_number_range_int = start_number_range.to_i
end_number_range_int = end_number_range.to_i

if end_number_range_int <= start_number_range_int then
  puts "Ending Formatted ID must be greater than starting Formatted ID. Exiting."
  exit
end

# Valid Artifact Types. Note that the following assumes
# Standard PI Types of Theme, Feature, and Initiative.
# If user has custom PI Types, the following list will need to be
# Customized to user environment
standard_types = ["US", "DE", "TA", "TC"]
pi_types = ["T", "I", "F"]

valid_types = [standard_types, pi_types].flatten

start_artifact_type_match = valid_types.include? start_artifact_type
end_artifact_type_match = valid_types.include? end_artifact_type

if start_artifact_type_match === false || end_artifact_type_match === false then
  puts "Invalid artifact type specified in either starting or ending Formatted ID."
  puts "Valid Formatted ID Prefix types include:"
  puts "#{valid_types}."
  puts "Exiting."
  exit
end

if start_artifact_type != end_artifact_type then
  puts "Starting and ending artifact types as specified by FormattedID must match."
  puts "Start type: #{start_artifact_type} != End type: #{end_artifact_type}."
  puts "Exiting."
  exit
end

valid_query_types = {
  "US" => :hierarchicalrequirement,
  "DE" => :defect,
  "TA" => :task,
  "TC" => :testcase,
  "F"  => "portfolioitem/feature",
  "I"  => "portfolioitem/initiative",
  "T"  => "portfolioitem/theme"
}
query_type = valid_query_types[start_artifact_type]

puts "Connecting to Rally: #{$my_base_url} as #{$my_username}..."
#==================== Make a connection to Rally ====================

#Setting custom headers
$headers                            = RallyAPI::CustomHttpHeader.new()
$headers.name                       = "Ruby Rally Artifact Bulk Delete Utility"
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

@rally = RallyAPI::RallyRestJson.new(config)

puts "Successfully connected to Rally."
puts "Querying for: #{query_type}s..."

query_string = "((FormattedID >= #{start_number_range}) AND (FormattedID <= #{end_number_range}))"

# Lookup source range for deletion
artifact_query = RallyAPI::RallyQuery.new()
artifact_query.type = query_type
artifact_query.fetch = "ObjectID,FormattedID,Name"
artifact_query.order = "FormattedID Asc"
artifact_query.project_scope_down = $project_scope_down
artifact_query.query_string = query_string

artifact_query_results = @rally.find(artifact_query)

number_of_artifacts = artifact_query_results.total_result_count

if number_of_artifacts == 0
  puts "No artifacts found in range: #{start_formatted_id} to #{end_formatted_id}. Exiting."
  exit
end

puts "Found #{number_of_artifacts} artifacts for possible deletion."
puts "Start processing deletions..."

# Loop through matching artifacts and delete them. Prompt user
# for each deletion.

number_processed = 0
number_deleted = 0
affirmative_answer = "y"

artifact_query_results.each do | this_artifact |

  number_processed += 1
  puts "Processing deletion for artifact #{number_processed} of #{number_of_artifacts}."

  artifact_formatted_id = this_artifact["FormattedID"]
  artifact_name = this_artifact["Name"]
  puts "Deleting artifact #{artifact_formatted_id}: #{artifact_name}..."
  really_delete = [(print "Really delete? [N/y]:"), gets.rstrip][1]

  if really_delete.downcase == affirmative_answer then
  begin
    delete_result = @rally.delete(this_artifact["_ref"])
    puts "DELETED #{artifact_formatted_id}: #{artifact_name}"
    number_deleted += 1
  rescue => ex
    puts "Error occurred trying to delete: #{artifact_formatted_id}: #{artifact_name}"
    puts ex
    puts "Note that this error will occur if a Parent and Child are both specified in the Range of"
    puts "input Formatted ID's. If the Parent is deleted before the Child, the Child item will"
    puts "be deleted along with it, and the subsequent deletion attempt on the Child will fail"
    puts "to find the Child Artifact. This is normal behavior and is a limitation of this script."
  end
  else
    puts "Did NOT delete #{artifact_formatted_id}: #{artifact_name}."
  end
end

puts
puts "Deleted a total of #{number_deleted} Artifacts."
puts "Complete!"