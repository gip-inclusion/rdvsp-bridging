module UsagerImports
  # Usagers known in an RDV-SP organisation, matched by e-mail, phone (last nine digits) or full name (case and accents
  # ignored): a homonym is better left out than created twice
  class UsagerIndex
    def initialize
      @usager_ids = {}
    end

    def add(first_name:, last_name:, email:, phone:, id: nil)
      keys_for(first_name:, last_name:, email:, phone:).each { @usager_ids[it] = id unless @usager_ids.key?(it) }
      self
    end

    def add_usager(usager)
      add(first_name: usager["first_name"], last_name: usager["last_name"], email: usager["email"],
          phone: usager["phone_number_formatted"].presence || usager["phone_number"], id: usager["id"])
    end

    def add_person(person) = add(**contact(person))

    def include?(person) = keys_for(**contact(person)).any? { @usager_ids.key?(it) }

    # The usager with the person's e-mail or phone: one with the same name only may be someone else
    def usager_id(person)
      keys_for(**contact(person)).reject { it.start_with?("name:") }.filter_map { @usager_ids[it] }.first
    end

    private

    def contact(person) = person.to_h.slice(:first_name, :last_name, :email, :phone)

    def keys_for(first_name:, last_name:, email:, phone:)
      digits = phone.to_s.gsub(/\D/, "")
      full_name = [first_name, last_name].all?(&:present?) && "#{first_name} #{last_name}"
      name = I18n.transliterate(full_name).downcase.squish if full_name
      [
        ("email:#{email.to_s.strip.downcase}" if email.present?),
        ("phone:#{digits.last(9)}" if digits.size >= 9),
        ("name:#{name}" if name),
      ].compact
    end
  end
end
