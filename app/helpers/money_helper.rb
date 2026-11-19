module MoneyHelper
  def format_money(cents, currency = "EUR")
    "#{format('%.2f', cents.to_i / 100.0)} #{currency}"
  end
end
