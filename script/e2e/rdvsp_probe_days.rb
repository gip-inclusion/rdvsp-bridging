ActiveJob::Base.queue_adapter = :test
ctx = JSON.parse(File.read(ARGV[0]))
agent, motif, lieu = Agent.find(ctx["agent_id"]), Motif.find(ctx["motif_id"]), Lieu.find(ctx["lieu_id"])
paris = ActiveSupport::TimeZone["Europe/Paris"]
(Date.new(2026, 10, 20)..Date.new(2026, 11, 3)).each do |day|
  slots = CreneauxSearch::Calculator.available_slots(date_range: day..day, motif:, lieu:, agents: [agent])
  puts "#{day.strftime('%a %d')}: #{slots.map { it.starts_at.in_time_zone(paris).strftime('%H:%M') }.sort.join(' ')}" if slots.any?
end
puts agent.plage_ouvertures.map { [it.title, it.first_day, it.start_time.to_s, it.end_time.to_s, it.recurrence&.to_h] }.inspect
