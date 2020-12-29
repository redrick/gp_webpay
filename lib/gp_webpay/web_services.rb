require "nokogiri"
require "curb"
require "active_support/core_ext/hash"
require "gp_webpay/web_services/template"
require "gp_webpay/web_services/response"

module GpWebpay
  module WebServices
    extend ActiveSupport::Concern

    def send_request(request_xml)
      request = Curl::Easy.new(config.web_services_url)
      request.headers["Content-Type"] = "text/xml;charset=UTF-8"
      request.http_post(request_xml)
      request
    end

    ##
    # Expected output
    # <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
    #   <soapenv:Body>
    #     <ns2:echoResponse xmlns:ns2="http://gpe.cz/pay/pay-ws/core" xmlns="http://gpe.cz/pay/pay-ws/core/type"/>
    #   </soapenv:Body>
    # </soapenv:Envelope>
    ##
    def ws_echo
      get_params_from(send_request(template.echo).body_str)
    end

    def ws_process_recurring_payment
      attributes = request_attributes("recurring")
      raw_response = send_request(template.process_recurring_payment(attributes)).body_str
      get_params_from(raw_response)
    end

    def ws_process_regular_subscription_payment
      attributes = request_attributes("regular_subscription")
      raw_response = send_request(template.process_regular_subscription_payment(attributes)).body_str
      get_params_from(raw_response)
    end

    def ws_get_order_detail
      attributes = request_attributes("detail")
      raw_response = send_request(template.get_order_detail(attributes)).body_str
      get_params_from(raw_response)
    end

    def ws_get_order_state
      attributes = request_attributes("state")
      raw_response = send_request(template.get_order_state(attributes)).body_str
      get_params_from(raw_response)
    end

    def message_id
      "#{order_number}0100#{config.merchant_number}"
    end

    def bank_id
      "0100"
    end

    private

    def get_params_from(response)
      hash_response = Hash.from_xml(Nokogiri::XML(response).to_s)["Envelope"]["Body"]
      first_lvl_key = hash_response.keys.first
      hash_response = hash_response["#{first_lvl_key}"]
      second_lvl_key = hash_response.keys.last
      hash_response = hash_response["#{second_lvl_key}"]
      GpWebpay::WebServices::Response.new(hash_response)
    end

    def request_attributes(type = "")
      {
        message_id: message_id,
        merchant_number: config.merchant_number,
        order_number: order_number,
        merchant_order_number: merchant_order_number,
        master_order_number: master_order_number,
        amount: amount_in_cents,
        card_holder_name: card_holder.name,
        card_holder_email: card_holder.email,
        card_holder_phone_country: card_holder.phone_country,
        card_holder_phone: card_holder.phone,
        card_holder_mobile_phone_country: card_holder.mobile_phone_country,
        card_holder_mobile_phone: card_holder.mobile_phone,
        address_match: address_match,
        billing_name: billing.name,
        billing_address1: billing.address1,
        billing_city: billing.city,
        billing_postal_code: billing.postal_code,
        billing_country: billing.country,
        shipping_name: shipping.name,
        shipping_address1: shipping.address1,
        shipping_city: shipping.city,
        shipping_postal_code: shipping.postal_code,
        shipping_country: shipping.country,
        digest: ws_verification(type).digest,
        # Deprecated Attrs, will remove
        currency: currency,
      }
    end

    def config
      GpWebpay.config
    end

    def template
      GpWebpay::WebServices::Template.new
    end

    def ws_attributes(type)
      PaymentAttributes.new(self, true, type).to_h
    end

    def ws_verification(type)
      ::GpWebpay::Verification.new(ws_attributes(type))
    end
  end
end
