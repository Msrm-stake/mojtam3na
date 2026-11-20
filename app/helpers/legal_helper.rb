module LegalHelper
  # A company detail from config/legal.yml. Blanks that are not filled in yet are highlighted.
  def legal(key)
    text = Legal.value(key)
    Legal.placeholder?(key) ? content_tag(:mark, text, class: "legal-placeholder") : text
  end
end
