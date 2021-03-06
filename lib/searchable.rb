require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)
    where_keys = params.keys.map { |key| "#{key} = ?" }.join(" AND ")
    where_values = params.values

    results = DBConnection.execute(<<-SQL, *where_values)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{where_keys};
      SQL
      
    parse_all(results)
  end

end

class SQLObject
  extend Searchable
end
