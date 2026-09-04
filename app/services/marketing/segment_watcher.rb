module Marketing
  class SegmentWatcher
    def self.sync_person!(person)
      return unless CreamFeatures.enabled?(:journeys) || CreamFeatures.enabled?(:marketing_campaigns)

      workspace = person.workspace
      workspace.segments.where(record_type: "Person").find_each do |segment|
        in_segment = segment.resolve(workspace.people.where(id: person.id)).exists?
        membership = SegmentMembership.find_by(segment: segment, person: person)

        if in_segment && membership.nil?
          SegmentMembership.create!(
            workspace: workspace,
            segment: segment,
            person: person,
            entered_at: Time.current
          )
          JourneyTrigger.enqueue_segment_entry!(person: person, segment: segment)
        elsif !in_segment && membership
          membership.destroy
        end
      end
    end
  end
end
