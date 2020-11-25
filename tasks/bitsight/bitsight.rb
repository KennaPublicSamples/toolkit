# frozen_string_literal: true

require_relative "lib/bitsight_helpers"

module Kenna
  module Toolkit
    class BitsightTask < Kenna::Toolkit::BaseTask
      include Kenna::Toolkit::BitsightHelpers

      def self.metadata
        {
          id: "bitsight",
          name: "Bitsight",
          maintainers: ["jcran"],
          description: "This task connects to the Bitsight API and pulls results into the Kenna Platform.",
          options: [
            { name: "bitsight_api_key",
              type: "string",
              required: true,
              default: "",
              description: "This is the Bitsight key used to query the API." },
            { name: "bitsight_company_guid",
              type: "string",
              required: false,
              default: "",
              description: "This is the Bitsight company GUID used to query the API." },
            { name: "bitsight_benign_finding_grades",
              type: "string",
              required: false,
              default: "GOOD",
              description: "Any bitsight findings with this grade will be considered benign (comma delimited list)" },
            { name: "bitsight_create_benign_findings",
              type: "boolean",
              required: false,
              default: true,
              description: "Create (informational) vulns for findings labeled benign" },
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
            { name: "output_directory",
              type: "filename",
              required: false,
              default: "output/bitsight",
              description: "If set, will write a file upon completion. Path is relative to #{$basedir}" }
          ]
        }
      end

      def run(options)
        super

        kenna_api_host = @options[:kenna_api_host]
        kenna_api_key = @options[:kenna_api_key]
        kenna_connector_id = @options[:kenna_connector_id]
        bitsight_api_key = @options[:bitsight_api_key]
        bitsight_company_guid = @options[:bitsight_company_guid]
        bitsight_create_benign_findings = @options[:bitsight_create_benign_findings]
        benign_finding_grades = (@options[:bitsight_benign_finding_grades]).to_s.split(",")

        ### Basic Sanity checking
        if valid_bitsight_api_key?(bitsight_api_key)
          print_good "Valid key, proceeding!"
        else
          print_error "Unable to proceed, invalid key for Bitsight?"
          return
        end

        ### If we weren't passed an org, we'll need to get one
        unless bitsight_company_guid
          print_good "Getting my company's ID"
          bitsight_company_guid = get_my_company(bitsight_api_key)
          print_good "Got #{bitsight_company_guid}"
        end

        ### This does the work. Connects to API and shoves everything into memory as KDI
        @assets = []
        @vuln_defs = [] # currently a necessary side-effect
        print_good "Getting findings!"

        if @options[:debug]
          max_findings = 10_000
          print_debug "Debug mode, only getting #{max_findings} findings"
        else
          max_findings = 1_000_000
        end

        kdi_options = {
          bitsight_create_benign_findings: bitsight_create_benign_findings,
          benign_finding_grades: benign_finding_grades
        }

        get_bitsight_findings_and_create_kdi(bitsight_api_key, bitsight_company_guid, max_findings, kdi_options)

        ### Write KDI format
        kdi_output = { skip_autoclose: false, assets: @assets, vuln_defs: @vuln_defs }
        output_dir = "#{$basedir}/#{@options[:output_directory]}"
        filename = "bitsight.kdi.json"
        write_file output_dir, filename, JSON.pretty_generate(kdi_output)
        print_good "Output is available at: #{output_dir}/#{filename}"

        ### Finish by uploading if we're all configured
        return unless kenna_connector_id && kenna_api_host && kenna_api_key

        print_good "Attempting to upload to Kenna API at #{kenna_api_host}"
        upload_file_to_kenna_connector kenna_connector_id, kenna_api_host, kenna_api_key, "#{output_dir}/#{filename}"
      end
    end
  end
end
