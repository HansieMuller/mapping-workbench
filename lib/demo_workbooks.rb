require "caxlsx"

# Every identity is invented. Zero-prefixed 13-digit IDs are synthetic, not national IDs.
module DemoWorkbooks
  def self.write(path, variant: :mixed)
    package = Axlsx::Package.new
    book = package.workbook
    book.add_worksheet(name: "Results") do |sheet|
      sheet.add_row [ "Moonfern fictional results; confirm header row 3" ], types: [ :string, :string, :string ]
      sheet.add_row [], types: [ :string, :string, :string ]
      sheet.add_row [ "RaceNo", "Full Name", "ID Number", nil, "DOB", "RaceTime", "Finish Status", "Overall Position", "Club", "Category", "Category Position", "Gender", "Gender Position", "Permanent Number" ], types: [ :string, :string, :string ]
      time = variant == :updates ? "00:49:01" : "00:51:23"
      sheet.add_row [ "101", "Luma Quill", "0000000000001", "unused original note", Date.new(1991, 4, 12), time, "Finished", 1, "Moonfern Striders", "Open", 1, "F", 1, "DEMO-001" ], types: [ :string, :string, :string, :string, :date, :string, :string, :integer, :string, :string, :integer, :string, :integer, :string ]
      if variant == :conflict
        sheet.add_row [ "101", "Bramble Finch", "0000000000002", nil, "1991-04-12", "00:52:00" ], types: [ :string, :string, :string ]
        sheet.add_row [ "108", "Conflicting Person", "0000000000001", nil, "1991-04-12", "00:50:00" ], types: [ :string, :string, :string ]
      elsif variant != :updates
        sheet.add_row [ "102", "Orin Thistle", "0000000000002", nil, 33_012, 0.0416666667, "Finished", 2, " moonfern striders " ], types: [ :string, :string, :string ]
        sheet.add_row [ "103", "Vela Reed", "0000000000003", nil, "1994/02/08", nil, "Withdrawn during race" ], types: [ :string, :string, :string ]
        sheet.add_row [ nil, "Elo Moss", "0000000000004", nil, "1990-03-10", 3601, "Finished" ], types: [ :string, :string, :string ]
        sheet.add_row Array.new(14)
        sheet.add_row [ nil, nil, nil, nil, nil, nil, nil, nil, "Fictional timing note" ] if variant == :success
        if variant == :mixed
          sheet.add_row [ "105", "Invalid Date Fiction", "0000000000005", nil, "1992-02-30", "01:10:00" ], types: [ :string, :string, :string ]
          sheet.add_row [ "106", "Invalid Time Fiction", "0000000000006", nil, "1992-02-12", "00:61:00" ], types: [ :string, :string, :string ]
          sheet.add_row [ "107", nil, nil, nil, nil, "01:12:00" ], types: [ :string, :string, :string ]
        end
      end
    end
    book.add_worksheet(name: "Profiles") do |sheet|
      # The blank headings and AB column deliberately exercise provenance beyond Z.
      headers = [ "First Name", "Surname", "DOB", "Email", "Cell Number", "Club" ] + Array.new(21) + [ "Permanent Number" ]
      sheet.add_row headers
      sheet.add_row [ "Sable", "Cloud", "1989-01-03", "sable@example.test", "000-DEMO-001", "Lantern Harriers" ] + Array.new(21) + [ "DEMO-008" ]
    end
    book.add_worksheet(name: "Entries") do |sheet|
      sheet.add_row [ "Full Name", "DOB", "Race No", "Finish Status" ]
      sheet.add_row [ "Nova Briar", "1995-09-20", "201", "Unknown" ]
    end
    package.serialize(path.to_s)
  end
end
