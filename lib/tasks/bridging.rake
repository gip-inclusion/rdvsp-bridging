namespace :bridging do
  namespace :pipedrive do
    desc "Create or update a Pipedrive account from an admin API token"
    task :onboard, %i[api_token alert_email] => :environment do |_task, args|
      result = Pipedrive::Onboard.call(api_token: args[:api_token], alert_email: args[:alert_email])
      abort result.errors.to_sentence if result.failure?

      account = result.account
      puts "Account ##{account.id} #{account.name} (activity type: #{account.rdv_activity_type_key})"
      Pipedrive::Client.new(account.api_token).users.each { puts "  user #{it['id']}: #{it['name']} <#{it['email']}>" }
    end
  end

  namespace :connection do
    desc "Connect a provider user to an RDV-SP agent and print the CalDAV credentials"
    task :create, %i[account_id provider_user_id agent_email] => :environment do |_task, args|
      result = Connections::Create.call(account: Account.find(args[:account_id]),
                                        provider_user_id: args[:provider_user_id], agent_email: args[:agent_email])
      abort result.errors.to_sentence if result.failure?

      puts "URL:      #{Rails.configuration.x.base_url}#{result.connection.calendar_path}"
      puts "Username: #{result.connection.username}"
      puts "Password: #{result.password}"
    end
  end
end
