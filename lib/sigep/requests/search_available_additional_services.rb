module Correios
  module Sigep
    class SearchAvailableAdditionalServices < Helper
      def initialize(data = {})
        @show_request = data[:show_request]
        super()
      end

      def request
        puts xml if @show_request == true
        begin
          format_response(Sigep.client.call(
            :busca_servicos_adicionais_ativos,
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
          xml['soap'].Envelope(Sigep.namespaces) do
            xml['soap'].Body do
              xml['ns1'].buscaServicosAdicionaisAtivos
            end
          end
        end.doc.root.to_xml
      end

      def format_response(response)
        response = response[:busca_servicos_adicionais_ativos_response][:return]
        response = [response] if response.is_a?(Hash)

        { additional_services: format_additional_services(response) }
      end

      def format_additional_services(additional_services)
        additional_services.map do |additional_service|
          {
            code: additional_service[:codigo],
            description: additional_service[:descricao].encode(Encoding::UTF_8),
            initials: additional_service[:sigla]
          }
        end
      end
    end
  end
end
