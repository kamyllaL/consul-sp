namespace :location_tags do

  desc "Insere tags de localização - subprefeituras e distritos"
  task create: :environment do
    subprefectures = ["Aricanduva/Formosa/Carrão", "Butantã", "Campo Limpo",
      "Capela do Socorro", "Casa Verde", "Cidade Ademar", "Cidade Tiradentes",
      "Ermelino Matarazzo", "Freguesia/Brasilândia", "Guaianases", "Ipiranga",
      "Itaim Paulista", "Itaquera", "Jabaquara", "Jaçanã/Tremembé", "Lapa",
      "M Boi Mirim", "Mooca", "Parelheiro", "Penha", "Perus", "Pinheiros",
      "Pirituba/Jaraguá", "Santo Amaro", "São Mateus", "Sapopemba", "Sé",
      "Vila Maria/Vila Guilherme", "Vila Prudente"]

    subprefectures.each do |name|
      puts "Criando tag de subpreitura - #{name}"
      Tag.create(name: name, kind: "subprefecture")
    end

    districts = ["Aricanduva", "Carrão", "Vila Formosa", "Butantã", "Morumbi",
      "Raposo Tavares", "Rio Pequeno", "Vila Sônia", "Campo Limpo", "Capão Redondo",
      "Vila Andrade", "Cidade Dutra", "Grajaú", "Socorro", "Cachoeirinha", "Casa Verde",
      "Limão", "Cidade Ademar", "Pedreira", "Cidade Tiradentes", "Ermelino Matarazzo",
      "Ponte Rasa", "Brasilândia", "Freguesia do Ó", "Guaianazes", "Lajeado", "Cursino",
      "Ipiranga", "Sacomã", "Itaim Paulista", "Vila Curuçá", "Cidade Líder", "Itaquera",
      "José Bonifácio", "Parque do Carmo", "Jabaquara", "Jaçanã", "Tremembé", "Barra Funda",
      "Jaguara", "Jaguaré", "Lapa", "Perdizes", "Vila Leopoldina", "Jardim Ângela",
      "Jardim São Luís", "Água Rasa", "Belém", "Brás", "Mooca", "Pari", "Tatuapé", "Marsilac",
      "Parelheiros", "Artur Alvim", "Cangaíba", "Penha", "Vila Matilde", "Anhanguera", "Perus",
      "Alto de Pinheiros", "Itaim Bibi", "Jardim Paulista", "Pinheiros", "Jaraguá", "Pirituba",
      "São Domingos", "Mandaqui", "Santana", "Tucuruvi", "Campo Belo", "Campo Grande",
      "Santo Amaro", "Iguatemi", "São Mateus", "São Rafael", "Jardim Helena", "São Miguel",
      "Vila Jacuí", "Sapopemba", "Bela Vista", "Bom Retiro", "Cambuci", "Consolação", "Liberdade",
      "República", "Santa Cecília", "Sé", "Vila Guilherme", "Vila Maria", "Vila Medeiros", "Moema",
      "Saúde", "Vila Mariana", "São Lucas", "Vila Prudente"]

    districts.each do |name|
      puts "Criando tag de distritos - #{name}"
      Tag.create(name: name, kind: "district")
    end
    puts "Tarefa finalizada"
  end
end