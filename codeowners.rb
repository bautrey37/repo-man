require 'net/http'
require 'json'
require 'base64'
require 'set'
require 'optparse'
require 'pp'
require 'date'

# GitHub API configuration
GITHUB_API_URL = "https://api.github.com"
GITHUB_ORG = "salemove"

DOC_FILE_PATH = "docs/codeowners.md"

# Parse command line arguments
$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby codeowners.rb [options]"

  opts.on("-t", "--token TOKEN", "GitHub API Token") do |t|
    $options[:token] = t
  end

  opts.on("-r", "--repo REPO", "Specific repository to process") do |r|
    $options[:repo] = r
  end
end.parse!

# Check if token is provided
if $options[:token].nil?
  puts "Error: GitHub API Token is required. Use -t or --token to provide it."
  exit 1
end

GITHUB_TOKEN = $options[:token]

def github_request(path)
  uri = URI("#{GITHUB_API_URL}#{path}")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "token #{GITHUB_TOKEN}"
  request["Accept"] = "application/vnd.github+json"
  request["User-Agent"] = "Script"  # GitHub API requires a user agent

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  else
    puts "Error in request to #{path}: #{response.code} - #{response.message}"
    # puts "Response body: #{response.body}"
    {'message' => response.message}
  end
end

def get_repos
  repos = []
  page = 1

  loop do
    new_repos = github_request("/orgs/#{GITHUB_ORG}/repos?page=#{page}&per_page=100&type=all")
    break if new_repos.nil? || new_repos.empty?
    repos.concat(new_repos)
    page += 1
  end

  repos
end

# https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners#codeowners-file-location
def get_codeowners_content(repo)
  codeowners_paths = [
    ".github/CODEOWNERS", # primary location
    # "CODEOWNERS",
    # "docs/CODEOWNERS"
  ]

  codeowners_paths.each do |path|
    response = github_request("/repos/#{GITHUB_ORG}/#{repo['name']}/contents/#{path}")
    if response.is_a?(Hash) && response['content']
      return Base64.decode64(response['content'])
    elsif response.is_a?(Hash) && response['message'] == 'Not Found'
      next
    else
      puts "Unexpected response for #{repo['name']}/#{path}: #{response}"
    end
  end

  puts "CODEOWNERS file not found in #{repo['name']}"
  nil
end

def parse_codeowners(content)
  teams = Set.new
  main_owner = nil
  content.each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    parts = line.split(/\s+/)
    pattern = parts[0]
    owners = parts[1..-1]
    owners.each do |owner|
      if owner.start_with?('@') && owner[1..-1].start_with?('salemove/')
        team = owner[1..-1].split('/')[1]
        teams.add(team)
        main_owner = team if pattern == '*' && main_owner.nil?
      end
    end
  end
  [teams, main_owner]
end

def process_repo(repo)
  # Ignore archived repo
  if repo['archived']
    return { name: repo['name'], status: "archived" }
  end

  puts "Processing repository: #{repo['name']}"

  if repo['fork']
    return { name: repo['name'], status: "fork" }
  end

  codeowners_content = get_codeowners_content(repo)
  if codeowners_content
    teams, main_owner = parse_codeowners(codeowners_content)
    if teams.empty?
      puts "  No teams found in CODEOWNERS file"
      return { name: repo['name'], status: "no teams" }
    else
      puts "  Teams found: #{teams.to_a.join(', ')}"
      puts "  Main owner: #{main_owner || 'None'}"
      ownership_type = main_owner ? "main" : "partial"
      return { name: repo['name'], teams: teams, main_owner: main_owner, ownership_type: ownership_type }
    end
  else
    return { name: repo['name'], status: "no CODEOWNERS" }
  end

  # Ignore archived repo
  if repo['archived']
    return "archived"
  end

  puts "Processing repository: #{repo['name']}"

  if repo['fork']
    return "#{repo['name']} (fork)"
  end

  codeowners_content = get_codeowners_content(repo)
  if codeowners_content
    teams, main_owner = parse_codeowners(codeowners_content)
    if teams.empty?
      puts "  No teams found in CODEOWNERS file"
      return "#{repo['name']} (no teams)"
    else
      puts "  Teams found: #{teams.to_a.join(', ')}"
      puts "  Main owner: #{main_owner || 'None'}"
      ownership_type = main_owner ? "(main)" : "(partial)"
      return [repo['name'], teams, main_owner, ownership_type]
    end
  else
    return "#{repo['name']} (no CODEOWNERS)"
  end
end

def write_output_to_file(team_repos, repos_without_codeowners, forked_repos)
  File.open(DOC_FILE_PATH, 'w') do |file|
    file.puts "# CODEOWNERS"
    file.puts
    file.puts "Generated at #{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')} by the script in \"platform/scripts/codeowners.rb\"."
    file.puts
    file.puts "## Repositories grouped by team"
    team_repos.keys.sort.each do |team|
      file.puts "\n### Team: #{team}"
      file.puts
      team_repos[team].sort_by { |repo| repo[:name] }.each do |repo|
        if repo[:main_owner] == team
          file.puts "- **#{repo[:name]}**"
        else
          file.puts "- #{repo[:name]} (partial)"
        end
      end
    end

    file.puts "\n## Repositories without CODEOWNERS or teams"
    file.puts
    repos_without_codeowners.sort.each do |repo|
      file.puts "- #{repo}"
    end

    file.puts "\n## Forked repositories"
    file.puts
    forked_repos.sort.each do |repo|
      file.puts "- #{repo}"
    end
  end
  puts "Output written to #{DOC_FILE_PATH}"
end

def main
  if $options[:repo]
    repo = github_request("/repos/#{GITHUB_ORG}/#{$options[:repo]}")
    result = process_repo(repo)
    if result.is_a?(Array)
      puts "Repository: #{result[0]}"
      puts "Teams: #{result[1].to_a.join(', ')}"
      puts "Main owner: #{result[2] || 'None'}"
      puts "Ownership type: #{result[3]}"
    else
      puts result
    end
  else
    puts "Fetching repositories for organization: #{GITHUB_ORG}"
    repos = get_repos
    puts "Total repositories found: #{repos.length}"
    puts "Public repositories: #{repos.count { |repo| !repo['private'] }}"
    puts "Private repositories: #{repos.count { |repo| repo['private'] }}"
    puts "Archived repositories: #{repos.count { |repo| repo['archived'] }}"

    team_repos = Hash.new { |h, k| h[k] = [] }
    repos_without_codeowners = []
    forked_repos = []
    archived_repos = [] # ignore

    repos.each do |repo|
      result = process_repo(repo)
      if result[:teams]
        result[:teams].each do |team|
          team_repos[team] << result
        end
      else
        case result[:status]
        when "archived"
          archived_repos << result[:name]
        when "fork"
          forked_repos << result[:name]
        else
          repos_without_codeowners << result[:name]
        end
      end
    end

    write_output_to_file(team_repos, repos_without_codeowners, forked_repos)
  end
end

main
