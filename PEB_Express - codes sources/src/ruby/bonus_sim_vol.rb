# Simulateur de vol amélioré pour SketchUp 2017

module Guisse
  module PEBExpress
    # Ajout de extend self pour rendre les méthodes du module accessibles
    extend self

    class SimulateurVol
      def initialize
        @vitesse = 10.0
        @acceleration = 0.5
        @deceleration = 0.3
        @vitesse_max = 200.0
        @vitesse_min = 1.0
        @rotation_vitesse = 2.0
        @camera = Sketchup.active_model.active_view.camera
        @direction = @camera.direction
        @up = Geom::Vector3d.new(0, 0, 1)
        @right = @direction.cross(@up)
        @altitude = 1000.0
        @masse = 1000.0
        @portance = 0.0
        @gravite = 9.81
        @densite_air = 1.225
        @surface_aile = 20.0
        @coefficient_portance = 0.3
        @coefficient_trainee = 0.03
        @angle_attaque = 0.0
        @angle_roulis = 0.0
        @inertie = 0.95
        @sensibilite_controle = 0.05
        @conditions_meteo = {
          vent: Geom::Vector3d.new(0, 0, 0),
          turbulence: 0.0,
          visibilite: 10000.0
        }
      end

      def create_html_dialog_sim
        @dialog = UI::HtmlDialog.new(
          {
            :dialog_title => "Speed",
            :preferences_key => "com.example.flight_simulator",
            :scrollable => false,
            :resizable => false,
            :width => 200,
            :height => 200,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )
        
        html_content = <<-HTML
          <!DOCTYPE html>
          <html lang="fr">
          <head>
              <meta charset="UTF-8">
              <title>Speed</title>
              <style>
                  body {
                      margin: 0;
                      padding: 0;
                      display: flex;
                      flex-direction: column;
                      justify-content: center;
                      align-items: center;
                      height: 100vh;
                      background: #000;
                      overflow: hidden;
                  }
                  .speedometer {
                      position: relative;
                      width: 180px;
                      height: 180px;
                      background: radial-gradient(circle at center, #1a1a1a 0%, #000 70%);
                      border-radius: 50%;
                      border: 2px solid #333;
                      box-shadow: 0 0 20px rgba(0,255,0,0.3);
                      margin-bottom: 15px;
                  }
                  .speed {
                      position: absolute;
                      top: 50%;
                      left: 50%;
                      transform: translate(-50%, -50%);
                      font-family: 'Courier New', monospace;
                      font-size: 36px;
                      color: #0f0;
                      text-shadow: 0 0 10px #0f0;
                  }
                  .unit {
                      font-size: 16px;
                      margin-top: 5px;
                      color: #0f0;
                      opacity: 0.7;
                  }
                  .controls {
                      font-family: 'Courier New', monospace;
                      color: #0f0;
                      font-size: 12px;
                      text-align: center;
                      line-height: 1.5;
                      background: rgba(0,50,0,0.3);
                      padding: 8px;
                      border-radius: 5px;
                      border: 1px solid #0f0;
                  }
                  @keyframes glow {
                      0% { box-shadow: 0 0 20px rgba(0,255,0,0.3); }
                      50% { box-shadow: 0 0 30px rgba(0,255,0,0.5); }
                      100% { box-shadow: 0 0 20px rgba(0,255,0,0.3); }
                  }
                  .speedometer {
                      animation: glow 2s infinite;
                  }
              </style>
          </head>
          <body>
              <div class="speedometer">
                  <div class="speed">
                      <span id="vitesse">0</span>
                      <div class="unit">M/S</div>
                  </div>
              </div>
              <div class="controls">
                  "W" pour accélérer<br>
                  "X" pour freiner<br>
                  ← → ↑ ↓ pour diriger
              </div>
          </body>
          </html>
        HTML
      
        @dialog.set_html(html_content)
        @dialog.show
      end
      
      def update_html_interface
        if @dialog
          vitesse = @vitesse.round(0)
          js_command = "document.getElementById('vitesse').textContent = '#{vitesse}';"
          @dialog.execute_script(js_command)
        end
      end

      def update(keys)
        appliquer_controles(keys)
        move(keys)
        rotate(keys)
        appliquer_forces
        update_camera
        update_html_interface
      end


      private

      def appliquer_controles(keys)
        # Tangage (pitch)
        pitch_input = 0
        pitch_input -= @sensibilite_controle if keys.include?(:pitch_up)
        pitch_input += @sensibilite_controle if keys.include?(:pitch_down)
        @angle_attaque = @angle_attaque * @inertie + pitch_input * (1 - @inertie)
        @angle_attaque = [@angle_attaque, -Math::PI/4].max
        @angle_attaque = [@angle_attaque, Math::PI/4].min

        # Roulis (roll)
        roll_input = 0
        roll_input -= @sensibilite_controle if keys.include?(:roll_left)
        roll_input += @sensibilite_controle if keys.include?(:roll_right)
        @angle_roulis = @angle_roulis * @inertie + roll_input * (1 - @inertie)
        @angle_roulis = [@angle_roulis, -Math::PI/2].max
        @angle_roulis = [@angle_roulis, Math::PI/2].min
      end

      def move(keys)
        # Accélération en piqué
        acceleration_pique = Math.sin(@angle_attaque) * @gravite
        @vitesse += acceleration_pique * 0.1  # 0.1 est le pas de temps

        if keys.include?(:forward)
          @vitesse += @acceleration * (1 - @angle_attaque.abs / (Math::PI/4))
        elsif keys.include?(:backward)
          @vitesse -= @deceleration
        else
          @vitesse *= 0.99
        end
        @vitesse = [@vitesse, @vitesse_min].max
        @vitesse = [@vitesse, @vitesse_max].min
      end

      def rotate(keys)
        rotation = Geom::Transformation.new
        
        # Yaw (lacet)
        yaw_input = 0
        yaw_input -= @rotation_vitesse if keys.include?(:yaw_left)
        yaw_input += @rotation_vitesse if keys.include?(:yaw_right)
        yaw_angle = yaw_input * (1 - @vitesse / @vitesse_max)  # Moins sensible à haute vitesse
        rotation *= Geom::Transformation.rotation(@camera.eye, @up, yaw_angle.degrees)

        # Pitch (tangage)
        pitch_angle = @angle_attaque
        rotation *= Geom::Transformation.rotation(@camera.eye, @right, pitch_angle)

        # Roll (roulis)
        roll_angle = @angle_roulis
        rotation *= Geom::Transformation.rotation(@camera.eye, @direction, roll_angle)

        @direction = @direction.transform(rotation)
        @up = @up.transform(rotation)
        @right = @direction.cross(@up)
      end

      def appliquer_forces
        # Calcul de la portance
        coefficient_portance_effectif = @coefficient_portance * (1 + @angle_attaque * 5)  # Augmente avec l'angle d'attaque
        @portance = 0.5 * @densite_air * (@vitesse ** 2) * @surface_aile * coefficient_portance_effectif

        # Calcul de la traînée
        coefficient_trainee_effectif = @coefficient_trainee * (1 + (@angle_attaque ** 2) * 10)  # Augmente avec l'angle d'attaque
        trainee = 0.5 * @densite_air * (@vitesse ** 2) * @surface_aile * coefficient_trainee_effectif

        # Force résultante verticale
        force_verticale = @portance * Math.cos(@angle_roulis) - @masse * @gravite

        # Mise à jour de l'altitude
        @altitude += force_verticale / @masse * 0.1  # 0.1 est le pas de temps

        # Ajustement de la vitesse en fonction de la traînée
        @vitesse -= trainee / @masse * 0.1

        # Empêcher l'avion de passer sous le sol
        @altitude = [@altitude, 0].max
      end

      def appliquer_effets_atmospheriques
        # Appliquer le vent
        vent_effect = Geom::Vector3d.new(@conditions_meteo[:vent].x * 0.01,
                                        @conditions_meteo[:vent].y * 0.01,
                                        @conditions_meteo[:vent].z * 0.01)
        @direction = @direction + vent_effect
      
        # Appliquer la turbulence
        turbulence = rand(-@conditions_meteo[:turbulence]..@conditions_meteo[:turbulence])
        turbulence_vector = Geom::Vector3d.new(turbulence * 0.01, turbulence * 0.01, turbulence * 0.01)
        @direction = @direction + turbulence_vector
      
        # Normaliser le vecteur direction
        @direction.normalize!
      
        # Ajuster la visibilité
        view = Sketchup.active_model.active_view
        view.camera.aspect_ratio = view.vpwidth.to_f / view.vpheight
        view.camera.fov = 60 # Champ de vision en degrés
        view.camera.image_width = @conditions_meteo[:visibilite]
      end
      
      def update_camera
        new_eye = @camera.eye.offset(@direction, @vitesse)
        new_target = new_eye.offset(@direction, 1)
        appliquer_effets_atmospheriques
        @camera.set(new_eye, new_target, @up)
      end

    end

    class SimulateurVolTool

      @@instance = nil  # Variable de classe pour stocker l'instance active

      def self.instance
        @@instance
      end

      def initialize
        # Si une instance existe déjà, fermer sa fenêtre HTML
        if @@instance && @@instance.is_a?(SimulateurVolTool)
          dialog = @@instance.simulateurVol.instance_variable_get(:@dialog)
          dialog.close if dialog
        end
        
        @simulateurVol = SimulateurVol.new
        @keys = []
        @@instance = self
      end

      # Permet l'accès au simulateurVol pour la fermeture de la fenêtre
      attr_reader :simulateurVol

      def activate
        @active = true
        puts "Simulateur de vol activé. W pour accélérer, X pour freiner, flèches directionnelles pour diriger."
        @simulateurVol.create_html_dialog_sim
        update_loop
      end

      def deactivate(view)
        @active = false
        # Pour être sûr, ferme aussi la fenêtre associée au simulateurVol actuel
        if @simulateurVol && @simulateurVol.instance_variable_get(:@dialog)
          begin
            @simulateurVol.instance_variable_get(:@dialog).close
          rescue
            # Continue si une erreur survient lors de la fermeture
          end
        end
        @@instance = nil  # Réinitialise l'instance
        puts "Simulateur de vol désactivé."
      end

      def onKeyDown(key, repeat, flags, view)
        case key
        when 87 then @keys << :forward     # W
        when 88 then @keys << :backward    # S
        when 38 then @keys << :pitch_up    # Flèche haut
        when 40 then @keys << :pitch_down  # Flèche bas
        when 39 then @keys << :roll_right  # Flèche gauche (inversé)
        when 37 then @keys << :roll_left   # Flèche droite (inversé)
        when 27 then Sketchup.active_model.select_tool(nil) # Échap
        end
        @keys.uniq!
      end

      def onKeyUp(key, repeat, flags, view)
        case key
        when 87 then @keys.delete(:forward)     # W
        when 88 then @keys.delete(:backward)    # S
        when 38 then @keys.delete(:pitch_up)    # Flèche haut
        when 40 then @keys.delete(:pitch_down)  # Flèche bas
        when 39 then @keys.delete(:roll_right)  # Flèche gauche (inversé)
        when 37 then @keys.delete(:roll_left)   # Flèche droite (inversé)
        end
      end

      private

      def update_loop
        return unless @active
        @simulateurVol.update(@keys)
        Sketchup.active_model.active_view.refresh
        UI.start_timer(0, false) { update_loop }
      end

    end

    def start_simulateurVol
      # Force la fermeture de toute instance existante
      if SimulateurVolTool.instance
        Sketchup.active_model.select_tool(nil)
        SimulateurVolTool.instance.deactivate(nil) if SimulateurVolTool.instance.respond_to?(:deactivate)
      end
      
      # Crée une nouvelle instance
      tool = SimulateurVolTool.new
      tool.activate
      Sketchup.active_model.select_tool(tool)
    end


    # Ajouter un élément de menu pour démarrer le simulateurVol
    plugin_menu = UI.menu("Plugins")
    plugin_menu.add_item("SimulateurVol de Vol") { start_simulateurVol }

    puts "SimulateurVol de vol chargé. Allez dans Plugins > SimulateurVol de Vol pour commencer."
  end
end
