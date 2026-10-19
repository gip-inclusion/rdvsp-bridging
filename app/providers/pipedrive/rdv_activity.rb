module Pipedrive
  # Pipedrive activity attributes for an RDV. Without the account's `usager_details` option, nothing that could
  # identify the usager is sent: RDV-SP's non-sensitive summary ("RDV <motif>"), the RDV-SP links and visio URLs only.
  class RdvActivity
    DEFAULT_SUBJECT = "RDV Service Public".freeze
    RDVSP_LINK = /^Voir sur (?<name>[^:\n]+): (?<url>https?:\S+)$/

    def initialize(rdv, person_id: nil)
      @rdv = rdv
      @payload = rdv.payload || {}
      @account = rdv.connection.account
      @person_id = person_id
    end

    def attributes
      duration = ((@rdv.ends_at - @rdv.starts_at) / 60).round.clamp(1, (24 * 60) - 1)
      {
        subject:,
        type: @account.rdv_activity_type_key.presence || "meeting",
        owner_id: Integer(@rdv.connection.provider_user_id),
        due_date: @rdv.starts_at.utc.to_date.iso8601,
        due_time: @rdv.starts_at.utc.strftime("%H:%M"),
        duration: format("%<hours>02d:%<minutes>02d", hours: duration / 60, minutes: duration % 60),
        busy: true,
        done: false,
        note:,
        location:,
        participants: @person_id ? [{ person_id: Integer(@person_id), primary: true }] : nil,
      }.compact
    end

    private

    def summary = @payload["summary"].to_s

    def subject
      return summary.presence || DEFAULT_SUBJECT if @account.usager_details

      summary.start_with?("RDV ") ? summary : DEFAULT_SUBJECT
    end

    def location
      value = @payload["location"].to_s
      return if value.blank?
      return { value: } if @account.usager_details || value.match?(%r{\Ahttps?://\S+\z})

      nil
    end

    def note
      paragraphs = ["Rendez-vous pris sur RDV Service Public."]
      links.each do |link|
        paragraphs << %(Pour voir, déplacer ou annuler ce rendez-vous sur #{ERB::Util.h(link[:name])} :
          <a href="#{ERB::Util.h(link[:url])}">#{ERB::Util.h(link[:url])}</a>).squish
      end
      paragraphs << "Modifier ou supprimer cette activité dans Pipedrive n’a aucun effet sur le rendez-vous."
      paragraphs << ERB::Util.h(@payload["description"]).gsub("\n", "<br>") if details?
      paragraphs.map { "<p>#{it}</p>" }.join
    end

    def details? = @account.usager_details && @payload["description"].present?

    def links
      @payload["description"].to_s.to_enum(:scan, RDVSP_LINK).map { Regexp.last_match }
        .map { |match| { name: match[:name].strip, url: match[:url] } }
    end
  end
end
