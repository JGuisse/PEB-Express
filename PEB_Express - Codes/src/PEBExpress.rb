module Guisse
    module PEBExpress
      # Obtenir le chemin du dossier contenant ce fichier
      PLUGIN_PATH = File.dirname(__FILE__)
  
      # Liste des fichiers à charger (chemins relatifs)
      FILES_TO_LOAD = [
        'Metres PEB\calculations_export.rb',
        'Metres PEB\collect2XML.rb',
        'Metres PEB\face_extraction.rb',
        'Metres PEB\main_PEB_Express.rb',
        'Creation paroi\creation_paroi.rb'
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