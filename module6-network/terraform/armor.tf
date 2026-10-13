resource "google_compute_security_policy" "ai_app" {
  name        = "store-assistant-armor"
  description = "Edge policy for the store-assistant AI app"

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection (preconfigured WAF)"
    match {
      expr { expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})" }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "Block cross-site scripting (preconfigured WAF)"
    match {
      expr { expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})" }
    }
  }

  rule {
    action      = "throttle"
    priority    = 2000
    description = "Rate limit per client IP. AI calls are expensive; this caps cost abuse."
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 10
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 3000
    description = "Allow US clients only"
    match {
      expr { expression = "origin.region_code != 'US'" }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
  }
}
