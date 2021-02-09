# frozen_string_literal: true

require "httparty"
require_relative "../../../lib/kdi/kdi_helpers"

module Kenna
  module Toolkit
    module Veracode
      class Client
        include HTTParty
        include KdiHelpers

        APP_PATH = "/appsec/v1/applications"
        FINDING_PATH = "/appsec/v2/applications"
        HOST = "api.veracode.com"
        REQUEST_VERSION = "vcode_request_version_1"

        def initialize(id, key, output_dir, filename, kenna_api_host, kenna_connector_id, kenna_api_key)
          @id = id
          @key = key
          @output_dir = output_dir
          @filename = filename
          @kenna_api_host = kenna_api_host
          @kenna_connector_id = kenna_connector_id
          @kenna_api_key = kenna_api_key
        end

        def applications(page_size)
          app_request = "#{APP_PATH}?size=#{page_size}"
          url = "https://#{HOST}#{app_request}"
          app_list = []
          until url.nil?
            uri = URI.parse(url)
            auth_path = "#{uri.path}?#{uri.query}"
            response = http_get(url, hmac_auth_options(auth_path))
            result = JSON.parse(response.body)
            applications = result["_embedded"]["applications"]
            applications.lazy.each do |application|
              app_list << { "guid" => application.fetch("guid"), "name" => application["profile"]["name"] }
            end
            url = (result["_links"]["next"]["href"] unless result["_links"]["next"].nil?) || nil
          end
          app_list
        end

        def issues(app_guid, app_name, page_size)
          print_debug "pulling issues for #{app_name}"
          app_request = "#{FINDING_PATH}/#{app_guid}/findings?size=#{page_size}"
          url = "https://#{HOST}#{app_request}"
          until url.nil?
            uri = URI.parse(url)
            auth_path = "#{uri.path}?#{uri.query}"
            response = http_get(url, hmac_auth_options(auth_path))
            result = JSON.parse(response.body)
            findings = result["_embedded"]["findings"]
            findings.lazy.each do |finding|
              file = finding["finding_details"]["file_name"]
              finding_cat = finding["finding_details"]["finding_category"].fetch("name")
              scanner_score = finding["finding_details"].fetch("severity")
              cwe = finding["finding_details"]["cwe"].fetch("id")
              cwe = "CWE-#{cwe}"
              found_on = finding["finding_status"].fetch("first_found_date")
              last_seen = finding["finding_status"].fetch("last_seen_date")
              additional_information = {
                "issue_id" => finding.fetch("issue_id"),
                "description" => finding.fetch("description"),
                "violates_policy" => finding.fetch("violates_policy"),
                "severity" => scanner_score
              }
              additional_information.merge!(finding["finding_details"])
              additional_information.merge!(finding["finding_status"])

              asset = {

                "file" => file,
                "application" => app_name
              }

              # craft the vuln hash
              finding = {
                "scanner_identifier" => finding_cat,
                "scanner_type" => "veracode",
                "severity" => scanner_score,
                "created_at" => found_on,
                "last_seen_at" => last_seen,
                "additional_fields" => additional_information
              }

              finding.compact!

              vuln_def = {
                "scanner_identifier" => finding_cat,
                "scanner_type" => "veracode",
                "cwe_identifiers" => cwe,
                "name" => finding_cat
              }

              vuln_def.compact!

              # Create the KDI entries
              create_kdi_asset_finding(asset, finding)
              create_kdi_vuln_def(vuln_def)
            end
            url = (result["_links"]["next"]["href"] unless result["_links"]["next"].nil?) || nil
          end
          kdi_upload(@output_dir, "veracode_#{app_name}.json", @kenna_connector_id, @kenna_api_host, @kenna_api_key)
        end

        def kdi_kickoff
          kdi_connector_kickoff(@kenna_connector_id, @kenna_api_host, @kenna_api_key)
        end

        private

        def hmac_auth_options(api_path)
          { Authorization: veracode_signature(api_path) }
        end

        def veracode_signature(api_path)
          nonce = SecureRandom.hex
          timestamp = DateTime.now.strftime("%Q")
          request_data = "id=#{@id}&host=#{HOST}&url=#{api_path}&method=GET"

          encrypted_nonce = OpenSSL::HMAC.hexdigest(
            "SHA256", @key.scan(/../).map(&:hex).pack("c*"), nonce.scan(/../).map(&:hex).pack("c*")
          )
          encrypted_timestamp = OpenSSL::HMAC.hexdigest(
            "SHA256", encrypted_nonce.scan(/../).map(&:hex).pack("c*"), timestamp
          )
          signing_key = OpenSSL::HMAC.hexdigest(
            "SHA256", encrypted_timestamp.scan(/../).map(&:hex).pack("c*"), REQUEST_VERSION
          )
          signature = OpenSSL::HMAC.hexdigest(
            "SHA256", signing_key.scan(/../).map(&:hex).pack("c*"), request_data
          )

          "VERACODE-HMAC-SHA-256 id=#{@id},ts=#{timestamp},nonce=#{nonce},sig=#{signature}"
        end
      end
    end
  end
end
