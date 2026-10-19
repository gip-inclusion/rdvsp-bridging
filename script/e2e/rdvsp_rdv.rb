ActiveJob::Base.queue_adapter = :test
ctx = JSON.parse(File.read(ARGV[0]))
step = ARGV[1]
agent, motif, lieu = Agent.find(ctx["agent_id"]), Motif.find(ctx["motif_id"]), Lieu.find(ctx["lieu_id"])
paris = ActiveSupport::TimeZone["Europe/Paris"]

def run_caldav_exports
  adapter = ActiveJob::Base.queue_adapter
  jobs = adapter.enqueued_jobs.select { it[:job] == Caldav::ExportRdvToCaldavJob }
  jobs.each { |job| Caldav::ExportRdvToCaldavJob.perform_now(*ActiveJob::Arguments.deserialize(job[:args])) }
  adapter.enqueued_jobs.clear
  jobs.size
end

case step
when "create"
  user = agent.organisations.first.users.first
  rdv = Rdv.create!(starts_at: paris.local(2026, 10, 26, 9), duration_in_min: 60, motif:, lieu:, organisation_id: ctx["organisation_id"],
                    agent_ids: [agent.id], user_ids: [user.id], context: "e2e bridge", created_by: agent)
  puts "rdv #{rdv.id} uuid=#{rdv.uuid} exports=#{run_caldav_exports} caldav_url=#{rdv.agents_rdvs.first.reload.caldav_url}"
  File.write(ARGV[2], rdv.id.to_s)
when "move"
  rdv = Rdv.find(File.read(ARGV[2]))
  rdv.update!(starts_at: paris.local(2026, 10, 26, 11), ends_at: paris.local(2026, 10, 26, 12))
  puts "moved, exports=#{run_caldav_exports}"
when "cancel"
  rdv = Rdv.find(File.read(ARGV[2]))
  rdv.update!(status: "revoked")
  puts "cancelled, exports=#{run_caldav_exports}"
when "import"
  Redis.with_connection { it.del("latest_caldav_import:#{agent.id}") }
  Caldav::ImportAbsencesFromCaldavJob.perform_now(agent.id)
  puts "imported: " + ExternalCalendarEvent.where(agent:).order(:starts_at).map { "#{it.starts_at.in_time_zone(paris).strftime('%a %d %H:%M')}-#{it.ends_at.in_time_zone(paris).strftime('%H:%M')}" }.join(", ")
  day = Date.new(2026, 10, 26)
  slots = CreneauxSearch::Calculator.available_slots(date_range: day..day, motif:, lieu:, agents: [agent])
  puts "slots Mon 26: " + slots.map { it.starts_at.in_time_zone(paris).strftime("%H:%M") }.sort.join(" ")
  puts "last sync executions: " + ExternalCalendarSyncExecution.where(agent:).order(:id).last(2).map { [it.try(:successful), it.try(:logs) || it.try(:log)].inspect }.join(" | ")
end
