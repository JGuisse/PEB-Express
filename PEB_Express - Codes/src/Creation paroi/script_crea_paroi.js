// Fonction pour déterminer si un type de paroi est léger
function isParoiLegere(type) {
    return ['Fenetre', 'Porte', 'MurRideau'].includes(type);
}
  
  // Fonction d'initialisation
function initializePage() {
    var fenetreButton = document.querySelector('button[data-type="Fenetre"]');
    if (fenetreButton) {
      fenetreButton.classList.add('active');
      updateUIForParoiType();
    }
}
  
  // Fonction pour mettre à jour l'interface utilisateur en fonction du type de paroi
function updateUIForParoiType() {
    var activeButton = document.querySelector('#type-group button.active, #type-group-opaque button.active');
    if (!activeButton) return;
    var isLegere = isParoiLegere(activeButton.dataset.type);
    
    document.querySelector('.container').classList.add('color-pulse');
    
    var colorPickerContainer = document.getElementById('color-picker-container');
    colorPickerContainer.style.display = isLegere ? 'none' : 'block';
  
    if (isLegere) {
      colorPickerContainer.classList.remove('show');
    } else {
      showColorPicker();
    }
  
    var elementsToToggle = [
      document.getElementById('angle-group'),
      document.getElementById('creation-section'),
      document.querySelector('.optional-section')
    ];
  
    elementsToToggle.forEach(function(element) {
      element.classList.add('fade-transition', 'fade-out');
    });
  
    setTimeout(function() {
      document.getElementById('angle-group').style.display = isLegere ? 'block' : 'none';
      document.getElementById('creation-section').style.display = isLegere ? 'block' : 'none';
      
      var espaceAdjacentContainer = document.getElementById('espace-adjacent-container');
      var espaceAdjacentLabel = document.getElementById('espace-adjacent-label');
      var optionalSection = document.querySelector('.optional-section');
      
      if (isLegere) {
        espaceAdjacentLabel.textContent = 'Espace Adjacent';
        espaceAdjacentContainer.classList.remove('obligatoire');
        
        // Modification ici
        if (!optionalSection.contains(espaceAdjacentContainer)) {
          var titleElement = optionalSection.querySelector('h3');
          if (titleElement && titleElement.nextSibling) {
            optionalSection.insertBefore(espaceAdjacentContainer, titleElement.nextSibling);
          } else {
            optionalSection.appendChild(espaceAdjacentContainer);
          }
        }
      } else {
        espaceAdjacentLabel.textContent = 'Espace Adjacent (obligatoire)';
        espaceAdjacentContainer.classList.add('obligatoire');
        document.querySelector('.container').insertBefore(espaceAdjacentContainer, optionalSection);
      }
      
      elementsToToggle.forEach(function(element) {
        element.classList.remove('fade-out');
        element.classList.add('fade-in');
      });
  
      setTimeout(function() {
        elementsToToggle.forEach(function(element) {
          element.classList.remove('fade-transition', 'fade-in');
        });
      }, 300);
    }, 300);
}
  
  // Fonction pour mettre à jour le visualiseur d'angle
function updateAngleVisualizer() {
    var angle = parseFloat(document.getElementById('angle').value) || 0;
    var arrow = document.getElementById('angle-arrow');
    var northIndicator = document.getElementById('north-indicator');
    
    var rotation = 'rotate(' + angle + 'deg)';
    arrow.style.transform = rotation;
    northIndicator.style.transform = rotation;
}
  
  // Fonction pour basculer l'état actif des boutons dans un groupe
function toggleButtonGroup(groupId, clickedButton) {
    var buttons = document.querySelectorAll('#' + groupId + ' button');
    if (groupId === 'type-group' || groupId === 'type-group-opaque') {
      buttons.forEach(function(button) {
        button.classList.remove('active');
      });
      clickedButton.classList.add('active');
    } else {
      if (clickedButton.classList.contains('active')) {
        clickedButton.classList.remove('active');
      } else {
        buttons.forEach(function(button) {
          button.classList.remove('active');
        });
        clickedButton.classList.add('active');
      }
    }
}
  
  // Fonction pour réinitialiser les entrées
function resetInputs() {
    document.getElementById('indice_paroi').value = '01';
    document.getElementById('nom_paroi').value = '';
    document.getElementById('angle').value = '0';
    document.querySelectorAll('#espace-adjacent-group button, #etat-paroi-group button').forEach(function(btn) {
      btn.classList.remove('active');
    });
    updateAngleVisualizer();
}
  
  // Fonction pour afficher une bulle d'information
function showInfoBubble(message) {
    var infoBubble = document.getElementById('info-bubble');
    infoBubble.textContent = message;
    infoBubble.style.display = 'block';
    
    setTimeout(function() {
      infoBubble.style.display = 'none';
    }, 3000);
}
  
  // Fonction pour valider l'angle
function validateAngle(angle) {
    var parsedAngle = parseFloat(angle);
    return !isNaN(parsedAngle) && parsedAngle >= -360 && parsedAngle <= 360;
}
  
// Configuration de la roue de couleur
const canvas = document.getElementById('color-wheel');
const ctx = canvas.getContext('2d');
const centerX = canvas.width / 2;
const centerY = canvas.height / 2;
const radius = Math.min(centerX, centerY);

const colorIndicator = document.getElementById('color-indicator');
const brightnessSlider = document.getElementById('brightness-slider');

let selectedColor = { h: 0, s: 100, l: 50 };
let isMouseDown = false;

function drawColorWheel() {
    for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
            const dx = x - centerX;
            const dy = y - centerY;
            const distance = Math.sqrt(dx * dx + dy * dy);
            
            if (distance <= radius) {
                const hue = (Math.atan2(dy, dx) + Math.PI) / (Math.PI * 2);
                const sat = distance / radius;
                ctx.fillStyle = `hsl(${hue * 360}, ${sat * 100}%, 50%)`;
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }
}

function handleColorSelection(event) {
  const rect = canvas.getBoundingClientRect();
  const x = event.clientX - rect.left - centerX;
  const y = event.clientY - rect.top - centerY;
  
  const distance = Math.sqrt(x * x + y * y);
  if (distance <= radius) {
    const hue = (Math.atan2(y, x) + Math.PI) / (Math.PI * 2);
    const sat = distance / radius;
    
    selectedColor.h = hue * 360;
    selectedColor.s = sat * 100;
    
    updateColorPreview();
    updateBrightnessSlider();
    updateColorIndicator(event.clientX - rect.left, event.clientY - rect.top);
  }
}

function updateColorPreview() {
    const preview = document.getElementById('color-preview');
    preview.style.backgroundColor = `hsl(${selectedColor.h}, ${selectedColor.s}%, ${selectedColor.l}%)`;
}

function updateBrightnessSlider() {
    const gradientColor = `hsl(${selectedColor.h}, ${selectedColor.s}%, 50%)`;
    brightnessSlider.style.background = `linear-gradient(to right, black 0%, ${gradientColor} 50%, white 100%)`;
}

function updateColorIndicator(x, y) {
    colorIndicator.style.left = `${x - 5}px`;
    colorIndicator.style.top = `${y - 5}px`;
    colorIndicator.style.backgroundColor = `hsl(${selectedColor.h}, ${selectedColor.s}%, 50%)`;
}

canvas.addEventListener('mousedown', (event) => {
    isMouseDown = true;
    handleColorSelection(event);
});

canvas.addEventListener('mousemove', (event) => {
    if (isMouseDown) {
        handleColorSelection(event);
    }
});

canvas.addEventListener('mouseup', () => {
    isMouseDown = false;
});

canvas.addEventListener('mouseleave', () => {
    isMouseDown = false;
});

brightnessSlider.addEventListener('input', () => {
    selectedColor.l = parseInt(brightnessSlider.value);
    updateColorPreview();
});

// Initialisation
drawColorWheel();
updateColorPreview();
updateBrightnessSlider();

function updateColorPreview() {
    var preview = document.getElementById('color-preview');
    preview.style.backgroundColor = 'hsl(' + selectedColor.h + ',' + selectedColor.s + '%,' + selectedColor.l + '%)';
}

function updateBrightnessSlider() {
    var gradientColor = `hsl(${selectedColor.h}, ${selectedColor.s}%, 50%)`;
    brightnessSlider.style.background = `linear-gradient(to right, black 0%, ${gradientColor} 50%, white 100%)`;
}

function updateColorIndicator(x, y) {
    colorIndicator.style.left = (x - 5) + 'px';
    colorIndicator.style.top = (y - 5) + 'px';
    colorIndicator.style.backgroundColor = 'hsl(' + selectedColor.h + ',' + selectedColor.s + '%,50%)';
}

function showColorPicker() {
  var colorPicker = document.getElementById('color-picker-container');
  colorPicker.style.display = 'block';
  setTimeout(() => {
    colorPicker.classList.add('show');
  }, 10);
}

function hslToRgb(h, s, l) {
  var r, g, b;

  if (s == 0) {
    r = g = b = l;
  } else {
    function hue2rgb(p, q, t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    }

    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;

    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }

  return {
    r: Math.round(r * 255),
    g: Math.round(g * 255),
    b: Math.round(b * 255)
  };
}

// Fonction pour envoyer les données
function envoyerDonnees() {
  var activeButton = document.querySelector('#type-group button.active, #type-group-opaque button.active');
  var type = activeButton ? activeButton.dataset.type : null;
  var indice = document.getElementById('indice_paroi').value;
  var nom = document.getElementById('nom_paroi').value;
  var angle = document.getElementById('angle').value;
  var espaceAdjacentElement = document.querySelector('#espace-adjacent-group button.active');
  var espaceAdjacent = espaceAdjacentElement ? espaceAdjacentElement.dataset.space : null;
  var etatParoiElement = document.querySelector('#etat-paroi-group button.active');
  var etatParoi = etatParoiElement ? etatParoiElement.dataset.state : null;

  var isLegere = isParoiLegere(type);

  if (!type) {
    showInfoBubble("Veuillez sélectionner un type de paroi");
    return;
  }

  if (!nom.trim()) {
    showInfoBubble("Veuillez entrer un nom de paroi (attention '_' non-autorisé).");
    return;
  }

  if (!/^(0[1-9]|[1-9]\d)$/.test(indice)) {
    showInfoBubble("Veuillez sélectionner un indice entre 01 et 99 (Attention pas d'espace).");
    return;
  }

  if (isLegere && !validateAngle(angle)) {
    showInfoBubble("Veuillez entrer un angle valide pour les parois légères.");
    return;
  }

  if (!isLegere && !espaceAdjacent) {
    showInfoBubble("L'espace adjacent est obligatoire pour les parois opaques.");
    return;
  }

  if (isLegere && ((espaceAdjacent && !etatParoi) || (!espaceAdjacent && etatParoi))) {
    showInfoBubble("Pour les parois légères, si vous sélectionnez une option facultative, vous devez sélectionner les deux (Espace Adjacent et État de la Paroi).");
    return;
  }

  var couleur = null;
  if (!isLegere) {
    var rgb = hslToRgb(selectedColor.h / 360, selectedColor.s / 100, selectedColor.l / 100);
    couleur = rgb;
  }

  try {
    sketchup.appliquer_nom_et_couleur(type, indice, nom, isLegere ? parseFloat(angle) : null, espaceAdjacent, etatParoi, couleur);
  } catch (error) {
    console.error("Erreur lors de l'envoi des données :", error);
    showInfoBubble("Erreur lors de l'envoi des données.");
  }
}

// Fonction pour activer l'outil de création de paroi
function activerOutilCreationParoi() {
  var activeButton = document.querySelector('#type-group button.active, #type-group-opaque button.active');
  var type = activeButton ? activeButton.dataset.type : null;
  var indice = document.getElementById('indice_paroi').value;
  var nom = document.getElementById('nom_paroi').value;
  var angle = document.getElementById('angle').value;
  var espaceAdjacentElement = document.querySelector('#espace-adjacent-group button.active');
  var espaceAdjacent = espaceAdjacentElement ? espaceAdjacentElement.dataset.space : null;
  var etatParoiElement = document.querySelector('#etat-paroi-group button.active');
  var etatParoi = etatParoiElement ? etatParoiElement.dataset.state : null;
  var largeur = document.getElementById('largeur').value;
  var hauteur = document.getElementById('hauteur').value;

  if (!type) {
    showInfoBubble("Veuillez sélectionner un type de paroi");
    return;
  }

  if (!nom.trim()) {
    showInfoBubble("Veuillez entrer un nom de paroi (attention '_' non-autorisé).");
    return;
  }

  if (!/^(0[1-9]|[1-9]\d)$/.test(indice)) {
    showInfoBubble("Veuillez sélectionner un indice entre 01 et 99 (Attention pas d'espace).");
    return;
  }

  if (!isParoiLegere(type)) {
    showInfoBubble("La création de nouvelles parois n'est possible que pour les parois légères.");
    return;
  }

  if ((espaceAdjacent && !etatParoi) || (!espaceAdjacent && etatParoi)) {
    showInfoBubble("Si vous sélectionnez une caractéristique facultative, vous devez sélectionner les deux (Espace Adjacent et État de la Paroi).");
    return;
  }

  try {
    sketchup.creer_nouvelle_paroi(type, indice, nom, parseFloat(angle), espaceAdjacent, etatParoi, parseFloat(largeur), parseFloat(hauteur));
    showInfoBubble("Outil de création activé. Cliquez dans le modèle pour placer la nouvelle paroi.");
  } catch (error) {
    console.error("Erreur lors de l'activation de l'outil de création :", error);
    showInfoBubble("Erreur lors de l'activation de l'outil de création.");
  }
}

function updateNomParoi(nouveauNom) {
  document.getElementById('nom_paroi').value = nouveauNom;
}

function updateFacesModifiees(count) {
  showInfoBubble(count + " face(s) modifiée(s) avec succès !");
}

// Event listeners
document.getElementById('angle').addEventListener('input', updateAngleVisualizer);

document.getElementById('nom_paroi').addEventListener('input', function(e) {
  if (this.value.includes('_')) {
    showInfoBubble("Le caractère '_' n'est pas autorisé dans le nom de la paroi.");
    this.value = this.value.replace(/_/g, '');
  }
});

document.querySelectorAll('#type-group button, #type-group-opaque button').forEach(function(button) {
  button.addEventListener('click', function() {
    var previousActiveButton = document.querySelector('#type-group button.active, #type-group-opaque button.active');
    var previousType = previousActiveButton ? previousActiveButton.dataset.type : null;
    
    document.querySelectorAll('#type-group button, #type-group-opaque button').forEach(function(btn) {
      btn.classList.remove('active');
    });
    this.classList.add('active');
    
    var newType = this.dataset.type;
    
    if (previousType === null || isParoiLegere(previousType) !== isParoiLegere(newType)) {
      updateUIForParoiType();
      resetInputs();
    }
  });
});

document.querySelectorAll('.button-group').forEach(function(group) {
  group.addEventListener('click', function(event) {
    var target = event.target;
    while (target !== this && !target.matches('button')) {
      target = target.parentNode;
    }
    if (target !== this) {
      toggleButtonGroup(this.id, target);
    }
  });
});

// Ajout d'un event listener pour le bouton de soumission
document.getElementById('submit-button').addEventListener('click', envoyerDonnees);

// Ajout d'un event listener pour le bouton de création de nouvelle paroi
document.getElementById('create-face-button').addEventListener('click', activerOutilCreationParoi);

// Initialisation de la page
document.addEventListener('DOMContentLoaded', initializePage);

updateColorPreview();
updateBrightnessSlider();

