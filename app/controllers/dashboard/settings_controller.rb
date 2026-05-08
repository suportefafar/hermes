module Dashboard
  class SettingsController < BaseController
    EDITABLE_KEYS = %w[rate_limit_per_minute fallback_threshold_pct max_retry_attempts].freeze

    def edit
      @settings = EDITABLE_KEYS.map do |key|
        SystemSetting.find_or_initialize_by(key: key).tap do |s|
          s.value ||= SystemSetting::DEFAULTS[key]
        end
      end
    end

    def update
      params[:settings]&.each do |key, value|
        next unless EDITABLE_KEYS.include?(key)
        SystemSetting.set(key, value)
      end

      redirect_to edit_dashboard_settings_path, notice: "Settings saved."
    end
  end
end
