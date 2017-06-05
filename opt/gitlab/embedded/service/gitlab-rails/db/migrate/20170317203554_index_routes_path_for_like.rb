# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class IndexRoutesPathForLike < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = false

  INDEX_NAME = 'index_routes_on_path_text_pattern_ops'

  disable_ddl_transaction!

  def up
    return unless Gitlab::Database.postgresql?

    unless index_exists?(:routes, :path, name: INDEX_NAME)
      execute("CREATE INDEX CONCURRENTLY #{INDEX_NAME} ON routes (path varchar_pattern_ops);")
    end
  end

  def down
    return unless Gitlab::Database.postgresql?

    if index_exists?(:routes, :path, name: INDEX_NAME)
      execute("DROP INDEX CONCURRENTLY #{INDEX_NAME};")
    end
  end
end
