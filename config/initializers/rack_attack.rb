class Rack::Attack
  # Rate limits for the API are handled via the background job scheduler.
  # Here we only throttle brute force attempts on the dashboard login page.

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      req.params['email'].to_s.downcase.gsub(/\s+/, "")
    end
  end
end
