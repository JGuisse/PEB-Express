module Guisse
    module PEBExpress
      # Obtenir le chemin du dossier contenant ce fichier
      PLUGIN_PATH = File.dirname(__FILE__)
  
      # Liste des fichiers à charger (chemins relatifs)
      FILES_TO_LOAD = [
        'ruby/metres_calculations_export.rb',
        'ruby/metres_collect2XML.rb',
        'ruby/metres_face_extraction.rb',
        'ruby/metres_main.rb',
        'ruby/crea_paroi_main.rb'
      ]
  
      # Chargement des fichiers
      FILES_TO_LOAD.each do |relative_path|
        full_path = File.join(PLUGIN_PATH, relative_path)
        begin
          load full_path
        rescue LoadError => e
          puts "Erreur lors du chargement de #{full_path}: #{e.message}"
        end
      end
    end
  end