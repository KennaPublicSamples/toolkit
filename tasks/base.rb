# frozen_string_literal: true

# require task-specific libraries etc

require "date"
require "base64"
require "tty-pager"

module Kenna
  module Toolkit
    class BaseTask
      include Kenna::Toolkit::Helpers
      include Kenna::Toolkit::KdiHelpers

      def self.inherited(base)
        Kenna::Toolkit::TaskManager.register(base)
      end

      # all tasks must implement a run method and call super, so
      # this code should be run immediately upon entry into the task
      def run(opts)
        # pull our required arguments out
        required_options = self.class.metadata[:options].select { |a| a[:required] }

        # colllect all the missing arguments
        missing_options = []
        required_options.each do |req|
          missing = true
          opts.each do |name, _value|
            missing = false if (req[:name]).to_s.strip == name.to_s.strip
          end
          missing_options << req if missing
        end

        # Task help!
        if opts[:help]
          print_task_help self.class.metadata[:id]
          print_good "Returning!"
          exit
        end

        # Task readme!
        if opts[:readme]
          print_readme self.class.metadata[:id]
          print_good "Returning!"
          exit
        end

        # if we do have missing ones, lets warn the user here and return
        unless missing_options.empty?
          print_error "Required options missing, cowardly refusing to continue!"
          missing_options.each do |arg|
            print_error "Missing! #{arg[:name]}: #{arg[:description]}"
          end
          exit
        end

        # No missing arguments, so let's add in our default arguments now
        self.class.metadata[:options].each do |o|
          print_good "Setting #{o[:name].to_sym} to default value: #{o[:default]}" unless o[:default] == "" || !o[:default]
          opts[o[:name].to_sym] = o[:default] unless opts[o[:name].to_sym]
          # but still set it to whatever
          # set empty string to nil so it's a little easier to check for that
          opts[o[:name].to_sym] = nil if opts[o[:name].to_sym] == ""
        end

        #### !!!!!!!
        #### Convert arguments to ruby types based on their type here
        #### !!!!!!!

        # Convert booleans to an actual false value
        opts.each do |oname, ovalue|
          # get the option specfics by iterating through our hash
          option_hash = self.class.metadata[:options].find { |a| a[:name] == oname.to_s.strip }
          next unless option_hash

          expected_type = option_hash[:type]
          next unless expected_type && expected_type == "boolean"

          case ovalue
          when "false"
            print_good "Converting #{oname} to false value" if opts[:debug]
            opts[oname] = false
          when "true"
            print_good "Converting #{oname} to true value" if opts[:debug]
            opts[oname] = true
          end
        end

        # if we made it here, we have the right arguments, and the right types!
        @options = opts

        # Print out the options so the user knows and logs what we're doing
        @options.each do |k, v|
          if k.includes("/key/") || k.includes("/token/") || k.includes("/secret/")
            print_good "Got option: #{k}: #{v[0]}*******#{v[-3..-1]}" if v
          else
            print_good "Got option: #{k}: #{v}"
          end
        end

        print_good ""
        print_good "Launching the #{self.class.metadata[:name]} task!"
        print_good ""
      end
    end
  end
end
