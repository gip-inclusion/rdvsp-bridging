# What an RDV received from RDV-SP may reveal in the partner's tool. Without the account's `usager_details` option,
# nothing that could identify the usager is passed on: RDV-SP's non-sensitive summary ("RDV <motif>"), the links
# back to RDV-SP and visio URLs only.
class RdvContent
  DEFAULT_SUBJECT = "RDV Service Public".freeze
  RDVSP_LINK = /Voir sur (?<name>[^:\n]+): (?<url>https?:\S+)/
  NOTICE = "Modifier ou supprimer cet événement ici n’a aucun effet sur le rendez-vous.".freeze

  def initialize(rdv)
    @payload = rdv.payload || {}
    @usager_details = rdv.connection.account.usager_details
  end

  def subject
    return summary.presence || DEFAULT_SUBJECT if @usager_details

    summary.start_with?("RDV ") ? summary : DEFAULT_SUBJECT
  end

  def location
    value = @payload["location"].to_s
    value if value.present? && (@usager_details || value.match?(%r{\Ahttps?://\S+\z}))
  end

  def links
    @payload["description"].to_s.to_enum(:scan, RDVSP_LINK).map { Regexp.last_match }
      .map { |match| { name: match[:name].strip, url: match[:url] } }
  end

  # Description as RDV-SP sent it, only with usager details
  def details = @usager_details ? @payload["description"].presence : nil

  def text
    paragraphs = ["Rendez-vous pris sur RDV Service Public."]
    links.each do |link|
      paragraphs << "Pour voir, déplacer ou annuler ce rendez-vous sur #{link[:name]} : #{link[:url]}"
    end
    paragraphs << NOTICE
    paragraphs << details if details
    paragraphs.join("\n\n")
  end

  def html
    paragraphs = ["Rendez-vous pris sur RDV Service Public."]
    links.each do |link|
      url = ERB::Util.h(link[:url])
      name = ERB::Util.h(link[:name])
      paragraphs << %(Pour voir, déplacer ou annuler ce rendez-vous sur #{name} : <a href="#{url}">#{url}</a>)
    end
    paragraphs << NOTICE
    paragraphs << ERB::Util.h(details).gsub("\n", "<br>") if details
    paragraphs.map { "<p>#{it}</p>" }.join
  end

  private

  def summary = @payload["summary"].to_s
end
