require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    table_rows = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      LIMIT 0;
    SQL

    table_rows.first.map(&:to_sym)
  end

  def self.finalize!
    define_method(:attributes) do
      @attributes ||= {}
    end

    columns.each do |column|
      define_method("#{column}=") do |value|
        attributes[column] = value
      end

      define_method(column) do
        attributes[column]
      end
    end
end

  def self.table_name=(table_name = self)
    name = table_name.to_s.tableize
    instance_variable_set(:@table_name, name)
  end

  def self.table_name
    name = instance_variable_get(:@table_name)
    name ||= self.to_s.tableize

    name
  end

  def self.all
    items = DBConnection.execute2(<<-SQL)
      SELECT
         DISTINCT "#{table_name}".*
      FROM
        #{table_name};
    SQL

    parse_all(items.drop(1)) #drop the header and turn the items into Ruby objects
  end

  def self.parse_all(results)
    objects = results.map do |items_hash|
      self.new(items_hash)
    end

    objects
  end

  def self.find(id)
    found = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = #{id};
    SQL

    return nil if found.empty?
    self.new(found.first)
  end

  def initialize(params = {})
      params.each do |attr_name, value|

        attr_name = attr_name.to_sym
        if self.class.columns.include?(attr_name)
          send "#{attr_name.to_s}=".to_sym, value
        else
          raise "unknown attribute '#{attr_name}'"
        end
      end

  end
  #
  # def attributes
  #   # ...
  # end

  def attribute_values
    attributes.values
  end

  def insert
    col_names =  attributes.keys.join(", ")
    update_attributes = attribute_values
    question_marks = (["?"] * attribute_values.length).join(", ")

    DBConnection.execute(<<-SQL, *update_attributes)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks});
      SQL

    self.id = DBConnection.last_insert_row_id

  end

  def update
    update_columns = attributes.keys.drop(1).map { |column| "#{column.to_sym} = ?" }.join(", ")
    update_attributes = attribute_values.rotate

    DBConnection.execute(<<-SQL, *update_attributes)
    UPDATE
      #{self.class.table_name}
    SET
      #{update_columns}
    WHERE
      id = ?;
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
