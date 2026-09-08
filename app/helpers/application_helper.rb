module ApplicationHelper
  def currency(val)
    ActionController::Base.helpers.number_to_currency(val)
  end

  # Renders one glyph from the inline sprite in application/_icon_sprite.
  # Pass :label to give the icon an accessible name; without one it is treated
  # as decorative and hidden from screen readers.
  def icon(name, css_class: nil, label: nil)
    attributes = { class: ["dd-icon", css_class].compact.join(" "), focusable: "false" }

    if label.present?
      attributes[:role] = "img"
    else
      attributes["aria-hidden"] = "true"
    end

    content_tag(:svg, attributes) do
      concat(content_tag(:title, label)) if label.present?
      concat(tag.use(href: "#i-#{name}"))
    end
  end

  # The fixed bottom nav highlights by controller/action rather than by path,
  # so the Lines tab stays lit while the sport and scope params change.
  def nav_current?(controller:, action: nil)
    return false unless controller_path == controller || controller_name == controller

    action.nil? || action_name == action
  end
end
