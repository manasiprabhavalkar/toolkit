# frozen_string_literal: true

require "csv"

module Kenna
  module Toolkit
    module Ssc
      class Client
        def initialize(key)
          @key = key
          @baseapi = "https://api.securityscorecard.io"
          @headers = {
            "Accept" => "application/json",
            "Content-Type" => "application/json",
            "Cache-Control" => "none",
            "Authorization" => "Token #{@key}"
          }
        end

        def successfully_authenticated?
          json = portfolios
          return true if json && json["entries"]

          false
        end

        def portfolios
          endpoint = "#{@baseapi}/portfolios"

          response = http_get(endpoint, @headers)

          JSON.parse(response.body.to_s)
        end

        def companies_by_portfolio(portfolio_id)
          endpoint = "#{@baseapi}/portfolios/#{portfolio_id}/companies"

          print_debug "Requesting #{endpoint}"

          response = http_get(endpoint, @headers)
          JSON.parse(response.body)
        end

        def issues_by_type_for_company(company_id, itype = "patching_cadence_low")
          endpoint = "#{@baseapi}/companies/#{company_id}/issues/#{itype}"
          response = http_get(endpoint, @headers, 0)
          JSON.parse(response.body.to_s) unless response.nil?
        end

        def issues_by_factors(detail_url, lookback)
          to_date = DateTime.now.strftime("%FT%T.%2NZ")
          from_date = (DateTime.now - lookback.to_i).strftime("%FT%T.%2NZ")
          final_url = "#{detail_url}?last_seen_time_from=#{from_date}&last_seen_time_to=#{to_date}"
          response = http_get(final_url, @headers)
          JSON.parse(response.body.to_s) unless response.nil?
        end

        def types_by_factors(company_id)
          endpoint = "#{@baseapi}/companies/#{company_id}/factors"
          response = http_get(endpoint, @headers)
          factors = JSON.parse(response.body.to_s)["entries"] unless response.nil?
          types = []
          factors.each do |factor|
            factor["issue_summary"]&.each do |detail|
              types << detail
            end
          end
          types
        end

        def issue_types_list(ssc_exclude_severity)
          endpoint = "#{@baseapi}/metadata/issue-types"

          response = http_get(endpoint, @headers)
          JSON.parse(response.body.to_s)["entries"].map { |x| x["key"] unless ssc_exclude_severity.include? x["severity"] }.compact
        end
      end
    end
  end
end
