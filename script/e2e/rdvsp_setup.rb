# Runs inside RDV-SP: configures CalDAV like Agents::CaldavSyncController, imports like the cron, searches slots
creds = JSON.parse(File.read(ARGV[0]))
ActiveJob::Base.queue_adapter = :test
day = Date.new(2026, 10, 21)
paris = ActiveSupport::TimeZone["Europe/Paris"]

base = PlageOuverture.where(title: "Permanence classique").where.not(lieu_id: nil).first
agent, lieu, motif = base.agent, base.lieu, base.motifs.where(location_type: :public_office).first
puts "agent=#{agent.email} motif=#{motif.name} lieu=#{lieu.name} org=#{base.organisation.name}"

PlageOuverture.where(title: "e2e bridge").destroy_all
begin; PlageOuverture.create!(title: "e2e bridge", organisation: base.organisation, agent:, lieu:, motif_ids: [motif.id],
                       first_day: day, start_time: Tod::TimeOfDay.new(9), end_time: Tod::TimeOfDay.new(12)); rescue ActiveRecord::RecordInvalid => e; puts "using existing plages (#{e.message})"; end

# Agents::CaldavSyncController#calendar_selection + #update (caldav_config_error)
probe = Calendav::Client.new(Calendav::Credentials::Standard.new(host: creds["url"].sub(%r{calendar/\z}, ""), username: creds["username"], password: creds["password"], authentication: :basic_auth))
calendars = probe.calendars.list.select { |c| c.components.include?("VEVENT") }
puts "calendar picker: #{calendars.map { [it.display_name, it.url, it.current_user_privilege_set.include?('write')] }}"
config = agent.caldav_config || agent.build_caldav_config
config.update!(caldav_agenda_url: calendars.first.url, caldav_username: creds["username"], caldav_password: creds["password"], caldav_sync_token: nil,
               caldav_calendar_name: calendars.first.display_name, caldav_calendar_color: calendars.first.color)
agent.reload
controller = Agents::CaldavSyncController.new
controller.params = ActionController::Parameters.new(caldav_agenda_url: agent.caldav_config.caldav_agenda_url)
controller.define_singleton_method(:current_agent) { agent }
puts "config check error: #{controller.send(:caldav_config_error).inspect}"

ExternalCalendarEvent.where(agent:).delete_all
Redis.with_connection { it.del("latest_caldav_import:#{agent.id}") }
Caldav::ImportAbsencesFromCaldavJob.perform_now(agent.id)
puts "imported: " + ExternalCalendarEvent.where(agent:).map { "#{it.starts_at.in_time_zone(paris).strftime('%a %d %H:%M')}-#{it.ends_at.in_time_zone(paris).strftime('%H:%M')}" }.join(", ")

slots = CreneauxSearch::Calculator.available_slots(date_range: day..day, motif:, lieu:, agents: [agent])
puts "slots on #{day}: " + slots.map { it.starts_at.in_time_zone(paris).strftime("%H:%M") }.sort.join(" ")
File.write(ARGV[1], { agent_id: agent.id, motif_id: motif.id, lieu_id: lieu.id, organisation_id: base.organisation_id }.to_json)
