# frozen_string_literal: true

module ActiveTableSet
  class QueryParser
    attr_reader :query, :read_tables, :write_tables, :operation, :clean_query

    def initialize(query)
      @query = query.dup.force_encoding("BINARY")
      @read_tables = []
      @write_tables = []
      @clean_query = strip_comments(query)
      parse_query
    end

    private

    MATCH_OPTIONALLY_QUOTED_TABLE_NAME = "[`]?([0-9,a-z,A-Z$_.]+)[`]?"

    SELECT_QUERY = /\A\s*select\s/i
    SELECT_FROM_MATCH = /FROM #{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    INSERT_QUERY = /\A\s*insert\s(?:ignore\s)?into/i
    INSERT_TARGET_MATCH = /\A\s*insert\s(?:ignore\s)?into\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    UPDATE_QUERY = /\A\s*update\s/i
    UPDATE_TARGET_MATCH = /\A\s*update\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    DELETE_QUERY = /\A\s*delete\s/i
    DELETE_TARGET_MATCH = /\A\s*delete.*from\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    DROP_QUERY = /\A\s*drop\s*table\s/i
    DROP_TARGET_MATCH = /\A\s*drop\s*table\s*(?:if\s+exists)?\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    CREATE_QUERY = /\A\s*create\s*table\s/i
    CREATE_TARGET_MATCH = /\A\s*create\s*table\s*(?:if\s+exists)?\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    TRUNCATE_QUERY = /\A\s*truncate\s*table\s/i
    TRUNCATE_TARGET_MATCH = /\A\s*truncate\s*table\s*\s#{MATCH_OPTIONALLY_QUOTED_TABLE_NAME}/i

    OTHER_SQL_COMMAND_QUERY = /\A\s*(?:begin|commit|end|release|savepoint|rollback|show|set|alter)/i

    JOIN_MATCH = /(?:left\souter)?\sjoin\s[`]?([0-9,a-z,A-Z$_.]+)[`]?/im

    def parse_query
      case
      when clean_query =~ SELECT_QUERY
        parse_select_query
      when clean_query =~ INSERT_QUERY
        parse_insert_query
      when clean_query =~ UPDATE_QUERY
        parse_update_query
      when clean_query =~ DELETE_QUERY
        parse_delete_query
      when clean_query =~ DROP_QUERY
        parse_drop_query
      when clean_query =~ CREATE_QUERY
        parse_create_query
      when clean_query =~ TRUNCATE_QUERY
        parse_truncate_query
      when clean_query =~ OTHER_SQL_COMMAND_QUERY
        @operation = :other
      else
        raise "ActiveTableSet::QueryParser.parse_query - unexpected query: #{query}"
      end
    end

    def strip_comments(source_query)
      source_query
        .scrub("*")
        .split("\n")
        .map { |row| row.strip.starts_with?("#") ? nil : row }
        .compact
        .join("\n")
    end

    def parse_select_query
      @operation = :select
      if clean_query =~ SELECT_FROM_MATCH
        @read_tables << Regexp.last_match(1)
      end
      parse_joins
    end

    def parse_insert_query
      @operation = :insert
      if clean_query =~ INSERT_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
      if clean_query =~ SELECT_FROM_MATCH
        @read_tables << Regexp.last_match(1)
      end
      parse_joins
    end

    def parse_update_query
      @operation = :update
      if clean_query =~ UPDATE_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
      parse_joins
    end

    def parse_delete_query
      @operation = :delete
      if clean_query =~ DELETE_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
      parse_joins
    end

    def parse_drop_query
      @operation = :drop
      if clean_query =~ DROP_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
    end

    def parse_create_query
      @operation = :create
      if clean_query =~ CREATE_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
    end

    def parse_truncate_query
      @operation = :truncate
      if clean_query =~ TRUNCATE_TARGET_MATCH
        @write_tables << Regexp.last_match(1)
      end
    end

    def parse_joins
      @read_tables += clean_query.scan(JOIN_MATCH).flatten
    end
  end
end
