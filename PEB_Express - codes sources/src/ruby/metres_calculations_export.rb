require 'csv'

module Guisse
  module PEBExpress
    LOCALISATION = "BX"

    class << self
      def calculate_ath_and_ratios(face_infos, unite_name)
        ath = 0
        surface_ach = 0
        surface_renovee = 0
        surface_neuve = 0
        nature_des_travaux = "Inconnu"
        longueur_fenetre_porte = 0
        ventilation_intensive = "Inconnu" 
        fenetres_saved = [] #Va permettre de détecter ou non la ventilation intensive

        face_infos.each_value do |face_info|
          if face_info[:group] == unite_name && ["EXT", "EANC", "IND", "SOL", "CAVE", "VV"].include?(face_info[:id_adjacent_space])
            surface = face_info[:area_m2]
            ath += surface
      
            case face_info[:face_statut]
            when "Renove"
              surface_renovee += surface
            when "Neuf"
              surface_neuve += surface
            end
          end

          if face_info[:group] == unite_name && face_info[:type_face] == "Plancher"
            surface_sol = face_info[:area_m2]
            surface_ach += surface_sol 
          end

          if face_info[:group] == unite_name && ["Fenetre", "Porte", "Mur rideau"].include?(face_info[:type_face])
            if face_info[:face_length].is_a?(Numeric)
              longueur_fenetre_porte += face_info[:face_length]
            end

            if face_info[:slope].to_f >= 15 && ["Fenetre", "Mur rideau"].include?(face_info[:type_face]) #Pas prise en compte des fenêtres horizontales et portes
              fenetres_saved << face_info
              ventilation_intensive = "Non" 
              if fenetres_saved.length > 1
                orientations = fenetres_saved.map { |face| face[:face_orientation] }
                orientations.combination(2).each do |o1, o2|
                  difference = (o1 - o2).abs
                  if difference > 80 && difference < 280
                    ventilation_intensive = "Oui"
                    break
                  end
                end
              end
            end
          end
        end
      
        rapport_r = ath.zero? ? 0 : (surface_renovee / ath).round(4)
        rapport_n = ath.zero? ? 0 : (surface_neuve / ath).round(4)

        if LOCALISATION == "BX"
          if rapport_n == 1
            nature_des_travaux = "UN"
          elsif rapport_n >= 0.75 
            nature_des_travaux = "UAN"
          elsif rapport_r + rapport_n >= 0.5
            nature_des_travaux = "URL"
          elsif rapport_r + rapport_n == 0
            nature_des_travaux = "Inconnu"
          else 
            nature_des_travaux = "URS"
          end
        end  

        {
          Ath: ath.round(2),
          surface_ach: surface_ach.round(2),
          RapportR: rapport_r,
          surface_renovee: surface_renovee.round(2),
          RapportN: rapport_n,
          surface_neuve: surface_neuve.round(2),
          nature_travaux: nature_des_travaux,
          longueur_fenetre_porte: longueur_fenetre_porte.round(2),
          ventilation_intensive: ventilation_intensive
        }
      end

      def export_to_csv(face_infos, unites_infos, fused_faces_infos, base_filename)
        separator = ";"
        date_prefix = Date.today.strftime("%y%m%d_")
        #filename1 = File.join(File.dirname(base_filename), "#{date_prefix}#{File.basename(base_filename, '.csv')}_original.csv")
        filename2 = File.join(File.dirname(base_filename), "#{date_prefix}#{File.basename(base_filename, '.csv')}.csv")

=begin  ==============FICHIER ALL NOT FUSED==============     
        filename1 = base_filename.sub('.csv', '_original.csv')
        File.open(filename1, "wb") do |file|
          file.write("\uFEFF")
          headers = ["Type", "Groupe", "Matériau", "Surface (m²)", "Centre X", "Centre Y", "Centre Z", 
                    "Groupes adjacents", "Type de paroi", "ID de la paroi", "ID Espace adjacent","Espace adjacent", 
                    "Etat de la paroi", "Orientation", "Longueur"]
          file.puts headers.join(separator)
      
          face_infos.each do |_, info|
            row = [
              "Face", 
              info[:group], 
              info[:material], 
              info[:area_m2].round(2).to_s.gsub('.', ','),
              info[:face_center][0].round(3).to_s.gsub('.', ','),
              info[:face_center][1].round(3).to_s.gsub('.', ','),
              info[:face_center][2].round(3).to_s.gsub('.', ','),
              info[:groupe_adjacent].join(', '),
              info[:type_face],
              info[:id_material],
              info[:id_adjacent_space],
              info[:adjacent_space],
              info[:face_statut],
              info[:face_orientation],
              info[:face_length].to_s.gsub('.', ',')
            ]
            file.puts row.join(separator)
          end
      
          file.puts ""
          file.puts ""
      
          file.puts "UNITÉS"
          headers = ["Type", "Nom", "Volume (m³)", "Ath (m²)","Surface Ach (m²)", "RapportR", "RapportN", "Nature des travaux"]
          file.puts headers.join(separator)
      
          unites_infos.each do |_, info|
            row = [
              "Unité",
              info[:name],
              info[:volume].round(3).to_s.gsub('.', ','),
              info[:Ath].to_s.gsub('.', ','),
              info[:surface_ach].to_s.gsub('.', ','),
              info[:RapportR].to_s.gsub('.', ','),
              info[:RapportN].to_s.gsub('.', ','),
              info[:nature_travaux].to_s.gsub('.', ',')
            ]
            file.puts row.join(separator)
          end
        end
=end    
        File.open(filename2, "wb") do |file|
          file.write("\uFEFF")
          
          file.puts "UNITÉS"
          headers = ["Type", "Nom", "Volume (m³)","Surface Ach (m²)", "Ath (m²)", "RapportR", "Surface Rénovée", "RapportN", "Surface Neuve", "Nature des travaux", "Ventilation intensive"]
          file.puts headers.join(separator)
      
          unites_infos.each do |_, info|
            row = [
              "Unité",
              info[:name],
              info[:volume].round(3).to_s.gsub('.', ','),
              info[:surface_ach].to_s.gsub('.', ','),
              info[:Ath].to_s.gsub('.', ','),
              info[:RapportR].to_s.gsub('.', ','),
              info[:surface_renovee].to_s.gsub('.', ','),
              info[:RapportN].to_s.gsub('.', ','),
              info[:surface_neuve].to_s.gsub('.', ','),
              info[:nature_travaux].to_s.gsub('.', ','),
              info[:ventilation_intensive].to_s.gsub('.', ',')
            ]
            file.puts row.join(separator)
          end

          file.puts ""
          file.puts "FACES"

          headers = ["Type", "Groupe", "Matériau", "Surface (m²)", "Groupes adjacents", 
                    "Type de paroi", "ID de la paroi", "ID Espace adjacent","Espace adjacent", 
                    "Etat de la paroi", "Orientation","Inclinaison", "Longueur", "PEB Name", "ID PEB", "ID meme face"]
          file.puts headers.join(separator)
      
          fused_faces_infos.each do |_, info|
            row = [
              info["Type"],
              info["Groupe"],
              info["Matériau"],
              info["Surface (m²)"].round(2).to_s.gsub('.', ','),
              info["Groupes adjacents"],
              info["Type de paroi"],
              info["ID de la paroi"],
              info["ID Espace adjacent"],
              info["Espace adjacent"],
              info["Etat de la paroi"],
              info["Orientation"],
              info["Inclinaison"],
              info["Longueur"].to_s.gsub('.', ','),
              info["Nom PEB"],
              info["ID PEB"],
              info["ID meme face"]
            ]
            file.puts row.join(separator)
          end
        end
        
        # puts "Données originales exportées dans #{filename1}"
        puts "Données fusionnées exportées dans #{filename2}"
      end
    end
  end
end
