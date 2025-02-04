# frozen_string_literal: true

require_relative '../test_helper'

module StatementInsurer
  class StatementInsurerTest < Minitest::Test
    def test_change_column_with_timeout
      @connection.create_table(:users) { |t| t.string :email }
      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            change_column :users, :email, :text
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }

      assert_calls [
        'ALTER TABLE "users" ALTER COLUMN "email" TYPE text',
      ], calls
    end

    def test_add_belongs_to
      @connection.create_table(:users)
      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            add_belongs_to(:users, :user, foreign_key: true)
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [
        # The column is added.
        'ALTER TABLE "users" ADD "user_id" bigint',

        # The index is created concurrently.
        'SET statement_timeout TO 0',
        'SET lock_timeout TO 0',
        'CREATE INDEX CONCURRENTLY "index_users_on_user_id" ON "users" ("user_id")',
        "SET lock_timeout TO '4950ms'",
        "SET statement_timeout TO '5s'",

        # The foreign key is added.
        'ALTER TABLE "users" ADD CONSTRAINT "fk_rails_6d0b8b3c2f" FOREIGN KEY ("user_id") ' \
        'REFERENCES "users" ("id") NOT VALID',
        'SET statement_timeout TO 0',
        'ALTER TABLE "users" VALIDATE CONSTRAINT "fk_rails_6d0b8b3c2f"',
        "SET statement_timeout TO '5s'",
      ], calls
    end

    def test_add_foreign_key_with_validate_explicitly_false
      @connection.create_table(:users) { |t| t.string :email }
      @connection.create_table(:messages) do |t|
        t.string :message
        t.bigint :user_id
      end

      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            add_foreign_key :messages, :users, validate: false
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [
        'ALTER TABLE "messages" ADD CONSTRAINT "fk_rails_273a25a7a6" FOREIGN KEY ("user_id") ' \
        'REFERENCES "users" ("id") NOT VALID',
      ], calls
    end

    def test_add_foreign_key
      @connection.create_table(:users) { |t| t.string :email }
      @connection.create_table(:messages) do |t|
        t.string :message
        t.bigint :user_id
      end

      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            add_foreign_key :messages, :users
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [
        'ALTER TABLE "messages" ADD CONSTRAINT "fk_rails_273a25a7a6" FOREIGN KEY ("user_id") ' \
        'REFERENCES "users" ("id") NOT VALID',
        'SET statement_timeout TO 0',
        'ALTER TABLE "messages" VALIDATE CONSTRAINT "fk_rails_273a25a7a6"',
        "SET statement_timeout TO '5s'",
      ], calls
    end

    def test_add_foreign_key_with_options
      @connection.create_table(:users, id: false) do |t|
        t.string :email
        t.bigint :real_id, primary_key: true
        t.bigint :other_id
      end
      @connection.create_table(:messages) do |t|
        t.string :message
        t.bigint :author_id
      end

      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            add_foreign_key :messages, :users, primary_key: :real_id, column: :author_id, name: :message_user_key
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [
        'ALTER TABLE "messages" ADD CONSTRAINT "message_user_key" FOREIGN KEY ("author_id") ' \
        'REFERENCES "users" ("real_id") NOT VALID',
        'SET statement_timeout TO 0',
        'ALTER TABLE "messages" VALIDATE CONSTRAINT "message_user_key"',
        "SET statement_timeout TO '5s'",
      ], calls
    end

    def test_add_foreign_key_with_validation
      @connection.create_table(:users) { |t| t.string :email }
      @connection.create_table(:messages) do |t|
        t.string :message
        t.bigint :user_id
      end

      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            add_foreign_key :messages, :users, validate: true
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [
        'ALTER TABLE "messages" ADD CONSTRAINT "fk_rails_273a25a7a6" FOREIGN KEY ("user_id") REFERENCES "users" ("id")',
      ], calls
    end

    def test_create_table
      @migration =
        Class.new(ActiveRecord::Migration::Current) do
          def change
            create_table(:users) do |t|
              t.string :email
              t.references :user, foreign_key: true
            end
          end
        end.new

      calls = record_calls(@connection, :execute) { run_migration }
      assert_calls [

        # Create the table with constraints.
        'CREATE TABLE "users" ("id" bigserial primary key, "email" character varying, "user_id" bigint, ' \
        'CONSTRAINT "fk_rails_6d0b8b3c2f" FOREIGN KEY ("user_id") REFERENCES "users" ("id") )',

        # Create the index.
        'SET statement_timeout TO 0',
        'SET lock_timeout TO 0',
        'CREATE INDEX "index_users_on_user_id" ON "users" ("user_id")',
        "SET lock_timeout TO '4950ms'",
        "SET statement_timeout TO '5s'",

      ], calls

      run_migration(:down)
      refute @connection.table_exists?(:users)
    end
  end
end
