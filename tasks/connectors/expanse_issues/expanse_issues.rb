# frozen_string_literal: true

# expanse client
require_relative "lib/expanse_issues_client"

# cloud exposure field mappings
require_relative "lib/expanse_issues_mapper"

module Kenna
  module Toolkit
    class ExpanseIssuesTask < Kenna::Toolkit::BaseTask
      include Kenna::Toolkit::ExpanseIssues::ExpanseIssuesMapper

      def self.metadata
        {
          id: "expanse_issues",
          name: "ExpanseIssues",
          description: "This task connects to the Expanse API and pulls results into the Kenna Platform.",
          options: [
            { name: "expanse_api_key",
              type: "string",
              required: true,
              default: "",
              description: "This is the Expanse key used to query the API." },
            { name: "issue_types",
              type: "string",
              required: false,
              default: "",
              description: "Comma-separated list of issue types. If not set, all issue types will be included" },
            { name: "priorities",
              type: "string",
              required: false,
              default: "",
              description: "Comma-separated list of priorities. If not set, all priorities will be included" },
            { name: "tagNames",
              type: "string",
              required: false,
              default: "",
              description: "Comma-separated list of tag names. If not set, all tags will be included" },
            { name: "lookback",
              type: "integer",
              required: false,
              default: 90,
              description: "Integer to retrieve the last n days of issues" },
            { name: "expanse_page_size",
              type: "integer",
              required: false,
              default: 10_000,
              description: "Comma-separated list of tag names. If not set, all tags will be included" },
            { name: "kenna_api_key",
              type: "api_key",
              required: false,
              default: nil,
              description: "Kenna API Key" },
            { name: "kenna_api_host",
              type: "hostname",
              required: false,
              default: "api.kennasecurity.com",
              description: "Kenna API Hostname" },
            { name: "kenna_connector_id",
              type: "integer",
              required: false,
              default: nil,
              description: "If set, we'll try to upload to this connector" },
            { name: "df_mapping_filename",
              type: "string",
              required: false,
              default: nil,
              description: "If set, we'll use this external file for vuln mapping - use with input_directory" },
            { name: "output_directory",
              type: "filename",
              required: false,
              default: "output/expanse",
              description: "If set, will write a file upon completion. Path is relative to #{$basedir}" }
          ]
        }
      end

      def run(options)
        super

        # Get options
        @kenna_api_host = @options[:kenna_api_host]
        @kenna_api_key = @options[:kenna_api_key]
        @kenna_connector_id = @options[:kenna_connector_id]
        @uploaded_files = []
        @output_dir = "#{$basedir}/#{@options[:output_directory]}"
        @issue_types = @options[:issue_types].split(",") if @options[:issue_types]
        @priorities =  @options[:priorities] if @options[:priorities]
        @tags = @options[:tagNames] if @options[:tagNames]
        expanse_api_key = @options[:expanse_api_key]

        print @issue_types
        print @priorities

        # create an api client
        @client = Kenna::Toolkit::ExpanseIssues::ExpanseIssuesClient.new(expanse_api_key)
        @fm = Kenna::Toolkit::Data::Mapping::DigiFootprintFindingMapper.new(@output_dir, @options[:input_directory], @options[:df_mapping_filename])

        @assets = []
        @vuln_defs = []

        # verify we have a good key before proceeding
        unless @client.successfully_authenticated?
          print_error "Unable to proceed, invalid key for Expanse?"
          return
        end
        print_good "Valid key, proceeding!"

        create_kdi_from_issues(@options[:expanse_page_size], @issue_types, @priorities, @tags, @fm, @options[:lookback])

        ####
        ### Finish by uploading if we're all configured
        ####
        return unless @kenna_connector_id && @kenna_api_host && @kenna_api_key

        kdi_kickoff
      end
    end
  end
end
