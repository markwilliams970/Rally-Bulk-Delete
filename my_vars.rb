$my_base_url        = "https://rally1.rallydev.com/slm"
$my_username        = "user@company.com"
$my_password        = "topsecret"
$my_workspace       = "My Workspace"
$my_project         = "My Project"
$project_scope_down = false
$wsapi_version      = "1.43"
$filename           = "items_to_delete.csv"

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