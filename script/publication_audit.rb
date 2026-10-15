require "open3"
require "zip"

# This supplements manual review. It is a bounded allowlist/pattern audit, not proof of absence.
FORBIDDEN = [ /-----BEGIN .*PRIVATE KEY/, /gh[pousr]_[A-Za-z0-9]{30,}/, /AKIA[A-Z0-9]{16}/,
  /(?:herokuapp\.com|amazonaws\.com|\bFinishTime\b|\bKOSMOS\b|perfectcircledesign)/i ].freeze
paths, status = Open3.capture2("git", "ls-files", "-z", "--cached", "--others", "--exclude-standard")
abort "Cannot enumerate intended files" unless status.success?
findings = []
paths.split("\0").each do |path|
  next unless File.file?(path)
  next if path == "script/publication_audit.rb"
  findings << "Unintended file: #{path}" if path.match?(%r{\A(?:log|tmp|storage)/.+}) && !path.end_with?(".keep")
  data = if path.end_with?(".xlsx")
    Zip::File.open(path) { |zip| zip.map { |entry| entry.get_input_stream.read }.join("\n") }
  elsif path.end_with?(".png")
    next # Genuine screenshots are inspected visually and manually reviewed before publication.
  else
    File.binread(path)
  end
  FORBIDDEN.each { |pattern| findings << "Restricted content: #{path}" if data.match?(pattern) }
end
# Scan every historic blob, including files later removed. Never print matching content.
commits, = Open3.capture2("git", "rev-list", "--all")
seen = {}
commits.lines.each do |commit|
  listing, = Open3.capture2("git", "ls-tree", "-r", commit.strip)
  listing.lines.each do |line|
    match = /\A\d+ blob ([a-f0-9]+)\t(.+)/.match(line)
    next unless match
    next if match[2] == "script/publication_audit.rb" || seen[match[1]]
    seen[match[1]] = true
    blob, = Open3.capture2("git", "cat-file", "blob", match[1])
    historical_data = if match[2].end_with?(".xlsx")
      xml = +""
      Zip::File.open_buffer(StringIO.new(blob.b)) { |zip| xml = zip.map { |entry| entry.get_input_stream.read }.join("\n") }
      xml
    else
      blob.b
    end
    FORBIDDEN.each { |pattern| findings << "Restricted historical blob: #{match[1]}" if historical_data.match?(pattern) }
    findings << "Credential file in history: #{match[2]}" if match[2].match?(%r{(?:master\.key|credentials.*|\.env)\z})
  end
end
abort findings.uniq.join("\n") unless findings.empty?
puts "Publication audit passed: intended files, generated workbook XML and complete fresh history."
