module Correios
  module ReverseLogistics
    class CreateShippingsWithCollection < Helper
      def initialize(data = {})
        @credentials = Correios.credentials
        @show_request = data[:show_request]

        @receiver = data[:receiver]
        @service_code = data[:service_code]
        @shippings = data[:shippings]
        super()
      end

      def request
        puts xml if @show_request == true
        begin
          format_response(ReverseLogistics.client.call(
            :solicitar_postagem_simultanea,
            soap_action: '',
            xml: xml
          ).to_hash)
        rescue Savon::SOAPFault => error
          generate_soap_fault_exception(error)
        rescue Savon::HTTPError => error
          generate_http_exception(error.http.code)
        end
      end

      private

      def xml
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soap'].Envelope(ReverseLogistics.namespaces) do
            xml['soap'].Body do
              xml['ns1'].solicitarPostagemSimultanea do
                parent_namespace = xml.parent.namespace
                xml.parent.namespace = nil

                xml.codAdministrativo @credentials.administrative_code
                xml.cartao @credentials.card
                xml.codigo_servico @service_code
                xml.destinatario do
                  receiver_address = @receiver[:address]
                  xml.nome @receiver[:name]
                  xml.ddd @receiver[:phone][0, 2]
                  xml.telefone @receiver[:phone][2, @receiver[:phone].length - 1]
                  xml.email @receiver[:email]
                  xml.logradouro receiver_address[:street]
                  xml.numero receiver_address[:number]
                  xml.complemento receiver_address[:additional]
                  xml.bairro receiver_address[:neighborhood]
                  xml.cidade receiver_address[:city]
                  xml.uf receiver_address[:state]
                  xml.cep receiver_address[:zip_code]
                  xml.referencia
                end
                @shippings.each do |shipping|
                  goods = shipping[:goods] || []
                  objects = shipping[:objects] || [{}]
                  xml.coletas_solicitadas do
                    xml.tipo reverse_shipping_type(shipping[:type])
                    xml.id_cliente shipping[:code]
                    xml.valor_declarado shipping[:declared_value]
                    xml.descricao shipping[:description]
                    xml.cklist shipping[:check_list]
                    xml.documento shipping[:document]
                    xml.obj shipping[:label_number]
                    xml.obs shipping[:note]
                    xml.remetente do
                      sender = shipping[:sender]
                      sender_address = shipping[:sender][:address]
                      xml.nome sender[:name]
                      xml.ddd sender[:phone][0, 2]
                      xml.telefone sender[:phone][2, sender[:phone].length - 1]
                      xml.ddd_celular sender[:cellphone][0, 2]
                      xml.celular sender[:cellphone][2, sender[:phone].length - 1]
                      xml.email sender[:email]
                      xml.sms bool_to_string(sender[:send_sms])
                      xml.identificacao sender[:document]
                      xml.logradouro sender_address[:street]
                      xml.numero sender_address[:number]
                      xml.complemento sender_address[:additional]
                      xml.bairro sender_address[:neighborhood]
                      xml.referencia
                      xml.cidade sender_address[:city]
                      xml.uf sender_address[:state]
                      xml.cep sender_address[:zip_code]
                    end
                    goods.each do |good|
                      xml.produto do
                        xml.codigo good[:code]
                        xml.tipo good[:type]
                        xml.qtd good[:amount]
                      end
                    end
                  end
                end

                xml.parent.namespace = parent_namespace
              end
            end
          end
        end.doc.root.to_xml
      end

      def format_response(response)
        response = response[:solicitar_postagem_simultanea_response][:solicitar_postagem_simultanea]
        generate_revese_logistics_exception(response)

        shippings = response[:resultado_solicitacao]
        shippings = [shippings] if shippings.is_a?(Hash)

        { shippings: shippings.map {|s| format_shipping(s)} }
      end

      def format_shipping(shipping)
        if shipping[:codigo_erro].to_i.zero?
          {
            type: inverse_reverse_shipping_type(shipping[:tipo]),
            code: shipping[:id_cliente],
            ticket_number: shipping[:numero_coleta],
            label_number: shipping[:numero_etiqueta],
            object_id: shipping[:id_obj],
            deadline: string_to_date(shipping[:prazo])
          }
        else
          {
            type: inverse_reverse_shipping_type(shipping[:tipo]),
            code: shipping[:id_cliente],
            error: shipping[:descricao_erro]
          }
        end
      end
    end
  end
end
