require_relative "../lib/demo_workbooks"
require "fileutils"
folder = File.expand_path("../test/fixtures/files", __dir__)
FileUtils.mkdir_p(folder)
[ :success, :mixed, :updates, :conflict ].each do |variant|
  DemoWorkbooks.write(File.join(folder, "#{variant}.xlsx"), variant: variant)
end
puts "Generated four entirely fictional XLSX workbooks."
