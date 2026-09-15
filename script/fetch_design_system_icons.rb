#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"
require "google/apis/drive_v3"
require "googleauth"
require "fileutils"

DESIGN_SYSTEM_FOLDER_ID = "1aoWXSfGD8K-0Df5KMFwBviTouIMxvgY2"
OUTPUT_DIR = Rails.root.join("public/design-system")
IMAGE_MIMES = %w[image/png image/jpeg image/svg+xml image/vnd.microsoft.icon image/x-icon].freeze
IMAGE_EXT = /\.(png|jpe?g|svg|ico)$/i
KEYWORDS = /logo|icon|favicon|marca|brand|app|cream/i

key_path = ENV.fetch("GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY_PATH")
abort "Missing service account key at #{key_path}" unless File.file?(key_path)

credentials = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(key_path),
  scope: Google::Apis::DriveV3::AUTH_DRIVE_READONLY
)
service = Google::Apis::DriveV3::DriveService.new
service.authorization = credentials

entries = []
queue = [[DESIGN_SYSTEM_FOLDER_ID, ""]]

until queue.empty?
  folder_id, prefix = queue.shift
  page_token = nil

  loop do
    response = service.list_files(
      q: "'#{folder_id}' in parents and trashed = false",
      fields: "nextPageToken, files(id,name,mimeType)",
      page_size: 200,
      page_token: page_token,
      supports_all_drives: true,
      include_items_from_all_drives: true
    )

    Array(response.files).each do |file|
      path = prefix.empty? ? file.name : "#{prefix}/#{file.name}"
      if file.mime_type == "application/vnd.google-apps.folder"
        queue << [file.id, path]
      elsif IMAGE_MIMES.include?(file.mime_type) || file.name.match?(IMAGE_EXT)
        entries << {path: path, id: file.id, mime_type: file.mime_type, name: file.name}
      end
    end

    page_token = response.next_page_token
    break unless page_token
  end
end

if entries.empty?
  abort "No image files found under design system folder #{DESIGN_SYSTEM_FOLDER_ID}"
end

FileUtils.mkdir_p(OUTPUT_DIR)

selected = entries.select { |entry| entry[:name].match?(KEYWORDS) || entry[:path].match?(KEYWORDS) }
selected = entries if selected.empty?

selected.sort_by { |entry| entry[:path] }.each do |entry|
  safe_name = entry[:path].gsub(%r{[^a-zA-Z0-9._-]+}, "_")
  destination = OUTPUT_DIR.join(safe_name)
  FileUtils.mkdir_p(destination.dirname)

  io = StringIO.new
  service.get_file(entry[:id], download_dest: io, supports_all_drives: true)
  File.binwrite(destination, io.string)

  puts "saved #{destination.relative_path_from(Rails.root)} (#{entry[:mime_type]})"
end

marketplace_dir = Rails.root.join("public/marketplace")
FileUtils.mkdir_p(marketplace_dir)

sources = Dir.glob(OUTPUT_DIR.join("**/*.{png,svg,ico}")).sort
png_sources = sources.select { |path| path.downcase.end_with?(".png", ".ico") }
best = png_sources.find { |path| path.match?(/128|96|512|logo|icon|favicon/i) } || png_sources.first

if best
  if best.end_with?(".ico")
    system("convert", "#{best}[4]", "-filter", "Lanczos", "-resize", "128x128", marketplace_dir.join("icon-128.png").to_s)
    system("convert", "#{best}[4]", "-filter", "Lanczos", "-resize", "96x96", marketplace_dir.join("icon-96.png").to_s)
    system("convert", "#{best}[2]", marketplace_dir.join("icon-32.png").to_s)
    system("convert", "#{best}[3]", marketplace_dir.join("icon-48.png").to_s)
  else
    system("convert", best, "-filter", "Lanczos", "-resize", "128x128", marketplace_dir.join("icon-128.png").to_s)
    system("convert", best, "-filter", "Lanczos", "-resize", "96x96", marketplace_dir.join("icon-96.png").to_s)
    system("convert", best, "-filter", "Lanczos", "-resize", "32x32", marketplace_dir.join("icon-32.png").to_s)
    system("convert", best, "-filter", "Lanczos", "-resize", "48x48", marketplace_dir.join("icon-48.png").to_s)
  end
  puts "generated marketplace icons in public/marketplace/"
end

banner_source = OUTPUT_DIR.join("brand_icon.png")
if File.file?(banner_source)
  system(
    "convert", "-size", "220x140", "xc:#f1f6fa",
    "(", banner_source.to_s, "-filter", "Lanczos", "-resize", "96x96", ")",
    "-gravity", "center", "-composite",
    marketplace_dir.join("card-banner-220x140.png").to_s
  )
  puts "generated marketplace card banner in public/marketplace/card-banner-220x140.png"
end
