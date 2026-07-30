class MigrateAlertRuleConditionsToAlertConditions < ActiveRecord::Migration[8.0]
  LEGACY_CONDITIONS = {
    "company_without_fiscal_info" => {
      field: "company.fiscal_information",
      operator: "blank",
      compare_value: nil
    },
    "deal_open" => {
      field: "open",
      operator: "eq",
      compare_value: "true"
    }
  }.freeze

  def up
    say_with_time "Migrating alert rule conditions to alert_conditions rows" do
      AlertRule.reset_column_information
      AlertCondition.reset_column_information

      AlertRule.find_each do |rule|
        Array(rule.conditions).each_with_index do |legacy_key, index|
          mapping = LEGACY_CONDITIONS[legacy_key.to_s]
          next unless mapping

          AlertCondition.create!(
            workspace_id: rule.workspace_id,
            alert_rule_id: rule.id,
            field: mapping[:field],
            operator: mapping[:operator],
            compare_value: mapping[:compare_value],
            active: true,
            position: index
          )
        end
      end
    end

    remove_column :alert_rules, :conditions, :jsonb, default: [], null: false
  end

  def down
    add_column :alert_rules, :conditions, :jsonb, default: [], null: false

    AlertCondition.find_each do |condition|
      legacy_key = LEGACY_CONDITIONS.find { |_, mapping|
        mapping[:field] == condition.field &&
          mapping[:operator] == condition.operator &&
          mapping[:compare_value] == condition.compare_value
      }&.first
      next unless legacy_key

      rule = condition.alert_rule
      rule.conditions = Array(rule.conditions) + [ legacy_key ]
      rule.save!(validate: false)
    end

    drop_table :alert_conditions
  end
end
