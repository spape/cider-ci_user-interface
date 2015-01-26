class CreateIssues < ActiveRecord::Migration
  def change
    create_table :execution_issues, id: :uuid do |t|
      t.text :description
      t.text :stacktrace
      t.string :type, null: false, default: 'error'
      t.uuid :execution_id, null: false
      t.index :execution_id
      t.timestamps
    end
    add_foreign_key :execution_issues, :executions, dependent: :delete
    remove_column :executions, :error, :text


    reversible do |dir| 

      dir.up do 
        execute "ALTER TABLE execution_issues ADD CONSTRAINT valid_type CHECK 
                ( type IN ('error', 'warning') )"

        execute "ALTER TABLE execution_issues ALTER COLUMN created_at SET DEFAULT now()";
        execute "ALTER TABLE execution_issues ALTER COLUMN updated_at SET DEFAULT now()";
        execute %[CREATE TRIGGER update_updated_at_column_of_execution_issues BEFORE UPDATE
                ON execution_issues FOR EACH ROW EXECUTE PROCEDURE 
                update_updated_at_column(); ]

        execute <<-SQL
          DROP VIEW  IF EXISTS  execution_cache_signatures;
          CREATE OR REPLACE VIEW execution_cache_signatures AS
          SELECT executions.id as execution_id,
          md5(string_agg(DISTINCT branches.updated_at::text,', 'ORDER BY branches.updated_at::text)) AS branches_signature,
          md5(string_agg(DISTINCT commits.updated_at::text,', 'ORDER BY commits.updated_at::text)) AS commits_signature,
          md5(string_agg(DISTINCT execution_issues.updated_at::text,', 'ORDER BY execution_issues.updated_at::text)) AS execution_issues_signature,
          count(DISTINCT execution_issues) AS execution_issues_count,
          md5(string_agg(DISTINCT repositories.updated_at::text,', 'ORDER BY repositories.updated_at::text)) AS repositories_signature,
          (SELECT (md5(string_agg(executions_tags.tag_id::text,',' ORDER BY tag_id))) FROM executions_tags WHERE executions_tags.execution_id = executions.id) AS tags_signature,
          (SELECT (count(DISTINCT tasks.id)::text || ' - ' || max(tasks.updated_at)::text ) FROM tasks WHERE tasks.execution_id = executions.id) as tasks_signature
          FROM executions
          LEFT OUTER JOIN execution_issues ON executions.id = execution_issues.execution_id
          LEFT OUTER JOIN commits ON executions.tree_id = commits.tree_id
          LEFT OUTER JOIN branches_commits ON branches_commits.commit_id = commits.id
          LEFT OUTER JOIN branches ON branches_commits.branch_id= branches.id
          LEFT OUTER JOIN repositories ON branches.repository_id= repositories.id
          GROUP BY executions.id;
        SQL
      end


      dir.down do
        execute <<-SQL
          DROP VIEW  IF EXISTS  execution_cache_signatures;
          CREATE OR REPLACE VIEW execution_cache_signatures AS
          SELECT executions.id as execution_id,
          md5(string_agg(DISTINCT branches.updated_at::text,', 'ORDER BY branches.updated_at::text)) AS branches_signature,
          md5(string_agg(DISTINCT commits.updated_at::text,', 'ORDER BY commits.updated_at::text)) AS commits_signature,
          md5(string_agg(DISTINCT repositories.updated_at::text,', 'ORDER BY repositories.updated_at::text)) AS repositories_signature,
          (SELECT (md5(string_agg(executions_tags.tag_id::text,',' ORDER BY tag_id))) FROM executions_tags WHERE executions_tags.execution_id = executions.id) AS tags_signature,
          (SELECT (count(DISTINCT tasks.id)::text || ' - ' || max(tasks.updated_at)::text ) FROM tasks WHERE tasks.execution_id = executions.id) as tasks_signature
          FROM executions
          LEFT OUTER JOIN commits ON executions.tree_id = commits.tree_id
          LEFT OUTER JOIN branches_commits ON branches_commits.commit_id = commits.id
          LEFT OUTER JOIN branches ON branches_commits.branch_id= branches.id
          LEFT OUTER JOIN repositories ON branches.repository_id= repositories.id
          GROUP BY executions.id;
        SQL
      end

    end
  end

end