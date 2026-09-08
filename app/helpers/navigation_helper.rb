module NavigationHelper
  def bottom_nav_items
    items = [
      { label: "Lines",       path: lines_path,          icon: "newspaper",
        active: nav_current?(controller: "lines") },
      { label: "Bet Slips",   path: bet_slip_wagers_path, icon: "receipt",
        active: nav_current?(controller: "wagers", action: "bet_slip") },
      { label: "History",     path: history_wagers_path,  icon: "clock-history",
        active: nav_current?(controller: "wagers", action: "history") },
      { label: "Leaderboard", path: leaderboard_path,     icon: "trophy",
        active: nav_current?(controller: "leaderboards") },
    ]

    if current_user&.admin?
      items << { label: "Admin", path: admin_dashboard_path, icon: "building",
                 active: controller_path.start_with?("admin/") }
    end

    items
  end
end
