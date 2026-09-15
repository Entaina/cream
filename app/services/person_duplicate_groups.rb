# Finds groups of Person records that share the same email in a workspace.
class PersonDuplicateGroups
  Group = Data.define(:email, :people) do
    def company_label
      names = people.map { |person| person.company.name }.uniq.sort
      (names.size == 1) ? names.first : names.join(", ")
    end
  end

  def self.call(workspace)
    new(workspace).call
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def call
    rows = workspace.person_emails
      .group(Arel.sql("LOWER(TRIM(person_emails.address))"))
      .having("COUNT(DISTINCT person_emails.person_id) > 1")
      .pluck(
        Arel.sql("LOWER(TRIM(person_emails.address))"),
        Arel.sql("ARRAY_AGG(DISTINCT person_emails.person_id ORDER BY person_emails.person_id)")
      )

    rows.filter_map do |normalized_email, person_ids|
      people = workspace.people
        .where(id: person_ids)
        .includes(:company, :owner, :deals, :person_emails)
        .order(:created_at, :id)
        .to_a

      Group.new(email: normalized_email, people: people)
    end.sort_by { |group| [group.company_label, group.email] }
  end

  private

  attr_reader :workspace
end
