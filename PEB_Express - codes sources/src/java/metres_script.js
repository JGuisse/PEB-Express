// Déclaration d'un objet global pour stocker les données
window.globalData = {
    currentUnitId: null
};

let globalTooltip;
let tooltipTimeout;
let lastTooltipTarget;
let updatePosition;

function populateTables(data) {
    const container = document.getElementById('tables_container');
    const groupList = document.getElementById('group_list');
    container.innerHTML = '';
    groupList.innerHTML = '';
    
    const { grouped_faces, unites_infos } = data;

    window.globalData.unites_infos = unites_infos;

    const fragment = document.createDocumentFragment();

    for (const group in grouped_faces) {
        if (grouped_faces.hasOwnProperty(group)) {
            const groupData = grouped_faces[group];
            const unitInfo = unites_infos.find(unit => unit.name === group);

            if (!unitInfo) {
                console.error('Informations de l\'unité non trouvées pour le groupe:', group);
                continue;
            }

            // Création de l'élément de liste pour l'accès rapide
            const listItem = createQuickAccessItem(group, unitInfo);
            groupList.appendChild(listItem);

            // Création du conteneur pour l'unité
            const unitContainer = document.createElement('div');
            unitContainer.className = 'unit-container';
            unitContainer.id = `unit-${unitInfo.entityId}`;

            // Création de l'ancre
            const anchor = document.createElement('div');
            anchor.id = 'anchor-' + group;
            anchor.className = 'unit-info-anchor';
            unitContainer.appendChild(anchor);

            // Création de la div d'information de l'unité
            const unitInfoDiv = createUnitInfoDiv(group, unitInfo);
            unitContainer.appendChild(unitInfoDiv);

            // Ajout du champ de commentaire
            const commentDiv = createCommentSection(unitInfo);
            unitContainer.appendChild(commentDiv);

            // Création de la table
            const tableContainer = document.createElement('div');
            tableContainer.className = 'table-container';
            createTable(tableContainer, groupData, group);
            unitContainer.appendChild(tableContainer);

            fragment.appendChild(unitContainer);
        }
    }

    container.appendChild(fragment);

    initializeTooltips();
    initializeCommentHeaders();

    // Récupérer l'ID de l'unité précédemment affichée
    const lastShownUnitId = localStorage.getItem('currentUnitId');

    // Vérifier si l'unité précédemment affichée existe toujours
    const unitStillExists = unites_infos.some(unit => unit.entityId.toString() === lastShownUnitId);

    if (lastShownUnitId && unitStillExists) {
        // Si l'unité précédente existe, l'afficher
        showUnit(lastShownUnitId);
    } else {
        // Sinon, afficher la première unité par défaut
        const firstUnitId = unites_infos.length > 0 ? unites_infos[0].entityId : null;
        if (firstUnitId) {
            showUnit(firstUnitId);
        }
    }
}


function createQuickAccessItem(group, unitInfo) {
    const listItem = document.createElement('li');
    listItem.className = 'quick-access-item';
    listItem.dataset.entityId = unitInfo.entityId;
    
    const link = document.createElement('a');
    link.href = '#';
    link.addEventListener('click', function(e) {
        e.preventDefault();
        showUnit(unitInfo.entityId);
    });
    
    let warningIcon = '';
    let moderateWarningIcon = '';
    
    if (unitInfo.warnings && unitInfo.warnings.length > 0) {
        warningIcon = '<i class="material-icons warning-icon">error</i>';
    }
    if (unitInfo.moderateWarnings && unitInfo.moderateWarnings.length > 0) {
        moderateWarningIcon = '<i class="material-icons warning-icon-moderate">warning</i>';
    }
    
    link.innerHTML = `<i class="material-icons">home</i>${group} ${warningIcon} ${moderateWarningIcon}`;
    listItem.appendChild(link);

    if (unitInfo.comment && unitInfo.comment.trim() !== '') {
        const commentIcon = document.createElement('i');
        commentIcon.className = 'material-icons quick-access-icon';
        commentIcon.textContent = 'comment';
        listItem.appendChild(commentIcon);
    }

    return listItem;
}

function createCommentSection(unitInfo) {
    console.log("Création de la section de commentaire pour:", unitInfo);
    const commentDiv = document.createElement('div');
    commentDiv.className = 'comment-section';
    commentDiv.dataset.entityId = unitInfo.entityId.toString(); // Assurez-vous que c'est une chaîne
    commentDiv.innerHTML = `
        <div class="comment-header">
            <span class="comment-icon ${unitInfo.comment ? 'has-comment' : ''}">
                <i class="material-icons">comment</i>
            </span>
            <span class="comment-toggle">Commentaire</span>
        </div>
        <div class="comment-content" data-loaded="false">
            <textarea id="comment_${unitInfo.entityId}" rows="4" lang="fr" spellcheck="true">${unitInfo.comment || ''}</textarea>
            <button class="save-comment-btn" onclick="saveComment('${unitInfo.entityId}')">
                <i class="material-icons">save</i>Sauvegarder
            </button>
        </div>
    `;
    return commentDiv;
}

function loadComment(entityId) {
    console.log("loadComment appelé pour entityId:", entityId);
    console.log("globalData disponible:", window.globalData);
    
    const commentContent = document.querySelector(`.comment-section[data-entity-id="${entityId}"] .comment-content`);
    if (!commentContent) {
        console.error(`Élément .comment-content non trouvé pour entityId: ${entityId}`);
        return;
    }
    
    if (commentContent.dataset.loaded === 'false') {
        console.log("Chargement du commentaire...");
        
        // Simulez un chargement asynchrone du commentaire
        setTimeout(() => {
            if (!window.globalData || !window.globalData.unites_infos) {
                console.error("globalData ou unites_infos non défini");
                commentContent.innerHTML = '<p>Erreur: Données non disponibles.</p>';
                return;
            }
            
            console.log("Recherche de l'unité pour entityId:", entityId);
            // Convertir entityId en nombre
            const numericEntityId = parseInt(entityId, 10);
            console.log("entityId converti en nombre:", numericEntityId);
            
            const unitInfo = window.globalData.unites_infos.find(unit => unit.entityId === numericEntityId);
            console.log("Unité trouvée:", unitInfo);
            
            if (unitInfo) {  //Spellcheck pour activer/désactiver correcteur d'orthographe
                commentContent.innerHTML = `
                    <textarea id="comment_${entityId}" rows="3" lang="fr" spellcheck="false">${unitInfo.comment || ''}</textarea>
                    <button class="save-comment-btn" onclick="saveComment('${entityId}')">
                        <i class="material-icons">save</i> Sauvegarder
                    </button>
                `;
                commentContent.dataset.loaded = 'true';
                autoResizeTextarea(commentContent.querySelector('textarea'));
                console.log("Commentaire chargé avec succès");
            } else {
                console.error(`Unité non trouvée pour l'entityId: ${entityId}`);
                commentContent.innerHTML = '<p>Erreur lors du chargement du commentaire.</p>';
            }
        }, 100);
    } else {
        console.log("Commentaire déjà chargé");
    }
}

function createTable(container, data, groupId) {
    const table = document.createElement('table');
    table.id = groupId;

    const thead = document.createElement('thead');
    thead.innerHTML = `
        <tr>
            <th>Unité</th>
            <th>Nom paroi</th>
            <th>Surface (m²)</th>
            <th>Groupes adjacents</th>
            <th>Type de paroi</th>
            <th>Espace adjacent</th>
            <th>Etat de la paroi</th>
            <th>Orientation/Inclinaison</th>
        </tr>
    `;
    table.appendChild(thead);

    const tbody = document.createElement('tbody');
    let currentParoiType = '';
    for (let i = 0; i < data.length; i++) {
        const face = data[i];
        if (face["Type de paroi"] !== currentParoiType) {
            currentParoiType = face["Type de paroi"];
            const typeRow = createParoiTypeRow(currentParoiType);
            tbody.appendChild(typeRow);
        }
        const row = createDataRow(face);
        tbody.appendChild(row);
    }
    table.appendChild(tbody);

    container.appendChild(table);
}

function showUnit(entityId) {
    const units = document.querySelectorAll('.unit-container');
    units.forEach(unit => {
        unit.style.display = 'none';
    });

    const unitToShow = document.getElementById(`unit-${entityId}`);
    if (unitToShow) {
        unitToShow.style.display = 'block';
        // Sauvegarder l'ID de l'unité actuelle dans localStorage
        localStorage.setItem('currentUnitId', entityId);

        const anchor = unitToShow.querySelector('.unit-info-anchor');
        if (anchor) {
            anchor.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    window.globalData.currentUnitId = entityId;

    // Mise à jour de la classe active dans la liste d'accès rapide
    const quickAccessItems = document.querySelectorAll('.quick-access-item');
    quickAccessItems.forEach(item => {
        item.classList.remove('active');
        if (item.dataset.entityId === entityId.toString()) {
            item.classList.add('active');
        }
    });
}


function initializeCommentHeaders() {
    document.querySelectorAll('.comment-header').forEach(header => {
        header.addEventListener('click', function() {
            const content = this.nextElementSibling;
            const entityId = this.closest('.comment-section').dataset.entityId;
            if (content.style.display === 'none' || content.style.display === '') {
                content.style.display = 'block';
                loadComment(entityId);
            } else {
                content.style.display = 'none';
            }
        });
    });
}

function createUnitInfoDiv(group, unitInfo) {
    const unitInfoDiv = document.createElement('div');
    unitInfoDiv.className = 'unit-info';
    
    const achValue = unitInfo.surface_ach !== undefined ? unitInfo.surface_ach : 0;
    const achModifiedClass = unitInfo.ach_modified ? 'ach-modified' : '';

    let warningHtml = '';
    let moderateWarningHtml = '';
    
    if (unitInfo.warnings && unitInfo.warnings.length > 0) {
        warningHtml = `
            <span class="warning-icon" data-tooltip="${unitInfo.warnings.join('<br>')}">
                <i class="material-icons">error</i>
            </span>
        `;
    }
    
    if (unitInfo.moderateWarnings && unitInfo.moderateWarnings.length > 0) {
        moderateWarningHtml = `
            <span class="warning-icon-moderate" data-tooltip="${unitInfo.moderateWarnings.join('<br>')}">
                <i class="material-icons">warning</i>
            </span>
        `;
    }
    
    unitInfoDiv.innerHTML = `
        <h2>${group} ${warningHtml} ${moderateWarningHtml}</h2>
        <div class="unit-info-grid">
            <div class="info-item">
                <span>Volume:</span>
                <span>${unitInfo.volume.toFixed(2)} m³</span>
            </div>
            <div class="info-item">
                <span>Surface Plancher<br>Chauffé (Ach):</span>
                <span class="editable-ach ${achModifiedClass}" data-entity-id="${unitInfo.entityId}" contenteditable="true">
                    ${achValue.toFixed(2)}
                </span> &nbsp <span>m²</span>         
            </div>
            <div class="info-item">
                <span>Surface de Déperditions<br>Thermiques (Ath):</span>
                <span>${unitInfo.Ath.toFixed(2)} m²</span>
            </div>
            <div class="info-item">
                <span>% Rénové :</span>
                <span>${(unitInfo.RapportR*100).toFixed(2)} %</span>
            </div>
            <div class="info-item">
                <span>% Neuf :</span>
                <span>${(unitInfo.RapportN*100).toFixed(2)} %</span>
            </div>
            <div class="info-item">
                <span>Nature des travaux - Bruxelles<br>(systèmes non pris en compte):</span>
                <span>${unitInfo.nature_travaux}</span>
            </div>
            <div class="info-item">
                <span>Longueur Fenêtres<br>& Portes:</span>
                <span>${unitInfo.longueur_fenetre_porte} m</span>
            </div>
            <div class="info-item">
                <span>Ventilation intensive<br>potentielle :</span>
                <span>${unitInfo.ventilation_intensive}</span>
            </div>
        </div>
    `;
    return unitInfoDiv;
}

function createParoiTypeRow(paroiType) {
    const typeRow = document.createElement('tr');
    const typeCell = document.createElement('td');
    typeCell.colSpan = 8;
    typeCell.className = 'paroi-type';
    typeCell.textContent = paroiType;
    typeRow.appendChild(typeCell);
    return typeRow;
}

function createDataRow(face) {
    const row = document.createElement('tr');
    
    row.innerHTML = `
        <td>${face["Groupe"]}</td>
        <td>
            ${face["Matériau"]}
            <button class="copy-button" data-text="${face["Nom PEB"]}" onclick="copyFromButton(this)">
                <i class="material-icons">content_copy</i>
            </button>
        </td>
        <td>${parseFloat(face["Surface (m²)"]).toFixed(2)}</td>
        <td>${face["Groupes adjacents"]}</td>
        <td>${face["Type de paroi"]}</td>
        <td>${face["Espace adjacent"]}</td>
        <td>${face["Etat de la paroi"]}</td>
        <td>${face["Orientation"]} / ${face["Inclinaison"]}</td>
    `;
    return row;
}

function copyFromButton(button) {
    const text = button.getAttribute('data-text');
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-9999px';
    
    document.body.appendChild(textArea);
    textArea.select();
    try {
        document.execCommand('copy');
        showNotification('Texte copié dans le presse-papiers');
    } catch (err) {
        console.error('Erreur lors de la copie dans le presse-papiers:', err);
    }
    document.body.removeChild(textArea);
}

function showNotification(message) {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.classList.add('show');
    setTimeout(() => {
        notification.classList.remove('show');
    }, 1500);
}

function createGlobalTooltip() {
    if (!globalTooltip) {
        globalTooltip = document.createElement('div');
        globalTooltip.className = 'global-tooltip';
        globalTooltip.style.position = 'fixed';
        globalTooltip.style.display = 'none';
        document.body.appendChild(globalTooltip);
    }
}

function showTooltip(target, content) {
    if (lastTooltipTarget === target) return;
    lastTooltipTarget = target;

    globalTooltip.innerHTML = content;
    globalTooltip.style.display = 'block';

    // Définition de updatePosition à l'intérieur de showTooltip
    updatePosition = () => {
        const rect = target.getBoundingClientRect();
        const tooltipRect = globalTooltip.getBoundingClientRect();

        let top = rect.top - tooltipRect.height - 10;
        let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2);

        if (top < 0) top = rect.bottom + 10;
        if (left < 0) left = 0;
        if (left + tooltipRect.width > window.innerWidth) {
            left = window.innerWidth - tooltipRect.width;
        }

        globalTooltip.style.top = `${top}px`;
        globalTooltip.style.left = `${left}px`;
    };

    updatePosition();
    window.addEventListener('scroll', updatePosition, { passive: true });
    window.addEventListener('resize', updatePosition, { passive: true });
}

function hideTooltip() {
    if (tooltipTimeout) {
        clearTimeout(tooltipTimeout);
    }
    tooltipTimeout = setTimeout(() => {
        globalTooltip.style.display = 'none';
        lastTooltipTarget = null;
        window.removeEventListener('scroll', updatePosition);
        window.removeEventListener('resize', updatePosition);
    }, 100);
}

function saveComment(entityId) {
    console.log('saveComment appelé avec entityId:', entityId);
    const commentElement = document.getElementById(`comment_${entityId}`);
    if (!commentElement) {
        console.error(`Élément avec id comment_${entityId} non trouvé`);
        return;
    }
    const comment = commentElement.value;
    console.log('Commentaire à sauvegarder:', comment);
    
    const callbackUrl = `skp:saveComment@${encodeURIComponent(entityId)}|||${encodeURIComponent(comment)}`;
    console.log('URL de callback:', callbackUrl);
    window.location.href = callbackUrl;
    
    // Mise à jour immédiate de l'interface utilisateur
    updateCommentUI(entityId, comment);
}

function updateCommentUI(entityId, comment) {
    console.log('updateCommentUI appelé avec entityId:', entityId, 'comment:', comment);
    const commentElement = document.getElementById(`comment_${entityId}`);
    if (commentElement) {
    commentElement.value = comment;
    autoResizeTextarea(commentElement);
    console.log('Valeur du commentaire mise à jour dans l\'élément HTML');
    } else {
    console.error(`Élément de commentaire non trouvé pour entityId: ${entityId}`);
    }
    
    updateCommentIcon(entityId, comment);
    updateQuickAccessIcon(entityId, comment);
    
    showNotification('Commentaire ' + (comment.trim() !== '' ? 'sauvegardé' : 'supprimé') + ' avec succès!');
}

function updateCommentIcon(entityId, comment) {
    const commentSection = document.querySelector(`.comment-section[data-entity-id="${entityId}"]`);
    if (commentSection) {
        const commentIcon = commentSection.querySelector('.comment-icon');
        if (commentIcon) {
            commentIcon.classList.toggle('has-comment', comment.trim() !== '');
        }
    }
}

function updateQuickAccessIcon(entityId, comment) {
    const quickAccessItem = document.querySelector(`.quick-access-item[data-entity-id="${entityId}"]`);
    if (quickAccessItem) {
        let iconElement = quickAccessItem.querySelector('.quick-access-icon');
        if (comment.trim() !== '') {
            if (!iconElement) {
                iconElement = document.createElement('i');
                iconElement.className = 'material-icons quick-access-icon';
                iconElement.textContent = 'comment';
                quickAccessItem.appendChild(iconElement);
            }
        } else if (iconElement) {
            iconElement.remove();
        }
    }
}

function showNotification(message) {
    const notificationElement = document.getElementById('notification');
    if (notificationElement) {
        notificationElement.textContent = message;
        notificationElement.style.display = 'block';
        setTimeout(() => {
            notificationElement.style.display = 'none';
        }, 3000);
    }
}

function showError(message) {
    showNotification(message);
    const notificationElement = document.getElementById('notification');
    if (notificationElement) {
        notificationElement.style.backgroundColor = '#f44336';
    }
}

function autoResizeTextarea(textarea) {
    textarea.style.height = 'auto'; // Réinitialise la hauteur
    textarea.style.height = (textarea.scrollHeight) + 'px'; // Ajuste la hauteur au contenu
}

function initializeAutoResizeTextareas() {
    document.querySelectorAll('.comment-content textarea').forEach(textarea => {
    textarea.addEventListener('input', function() {
        autoResizeTextarea(this);
    });
    // Initialise la taille au chargement
    autoResizeTextarea(textarea);
    });
}

function initializeTooltips() {
    createGlobalTooltip();
    const container = document.querySelector('.tables-container');

    container.addEventListener('mouseover', (event) => {
        const target = event.target.closest('.warning-icon, .warning-icon-moderate');
        if (target) {
            const tooltipContent = target.getAttribute('data-tooltip');
            clearTimeout(tooltipTimeout);
            tooltipTimeout = setTimeout(() => showTooltip(target, tooltipContent), 100);
        }
    });

    container.addEventListener('mouseout', (event) => {
        if (!event.relatedTarget || !event.relatedTarget.closest('.warning-icon, .warning-icon-moderate')) {
            hideTooltip();
        }
    });
}

document.addEventListener('DOMContentLoaded', function() {
    document.body.addEventListener('blur', function(event) {
        if (event.target.classList.contains('editable-ach')) {
            const entityId = event.target.dataset.entityId;
            const newValue = parseFloat(event.target.textContent);
            if (!isNaN(newValue)) {
                if (window.sketchup) {
                    // Appel à la fonction SketchUp pour sauvegarder la nouvelle valeur Ach
                    window.sketchup.saveAch(entityId, newValue);
                }
                event.target.classList.add('ach-modified');
                // Mise à jour de l'interface sans recharger toute la page
                updateAchUI(entityId, newValue);
            } else {
                if (window.sketchup) {
                    window.sketchup.resetAch(entityId);
                }
                showNotification('Valeur invalide. Calcul Ach par défaut. Rechargez la page pour mesurer Ach.');
            }
        }
    }, true);

    document.body.addEventListener('focus', function(event) {
        if (event.target.classList.contains('editable-ach')) {
            event.target.dataset.originalValue = event.target.textContent;
        }
    }, true);
});

function updateAchUI(entityId, newValue) {
    const achElement = document.querySelector(`.editable-ach[data-entity-id="${entityId}"]`);
    if (achElement) {
        achElement.textContent = parseFloat(newValue).toFixed(2);
        achElement.classList.add('ach-modified');
    }
}

document.getElementById('refresh_button').addEventListener('click', function() {
    if (window.sketchup) {
        window.sketchup.refreshData();
    }
});

document.getElementById('export_excel_button').addEventListener('click', function() {
    if (window.sketchup) {
        window.sketchup.exportExcel();
    }
});

document.getElementById('export_xml_button').addEventListener('click', function() {
    if (window.sketchup) {
        window.sketchup.exportXML();
    }
});

window.addEventListener('message', function(event) {
    if (event.data.type === 'populateTables') {
        populateTables(event.data.payload);
    }
});

// Fonction à appeler depuis SketchUp pour mettre à jour l'interface
function updateAchFromSketchUp(entityId, newValue) {
    console.log(`Mise à jour de l'Ach pour l'entité ${entityId} avec la nouvelle valeur ${newValue}`);
    const achElement = document.querySelector(`.editable-ach[data-entity-id="${entityId}"]`);
    if (achElement) {
        if (newValue === null) {
            // Réinitialisation à la valeur par défaut (vous devrez définir cette valeur)
            achElement.textContent = ''; // Ou une valeur par défaut si vous en avez une
            achElement.classList.remove('ach-modified');
            console.log('Valeur Ach réinitialisée');
        } else {
            achElement.textContent = parseFloat(newValue).toFixed(2);
            achElement.classList.add('ach-modified');
            console.log('Élément Ach mis à jour dans l\'interface');
        }
    } else {
        console.error(`Élément Ach non trouvé pour l'entité ${entityId}`);
    }
    showNotification(newValue === null ? 'La valeur Ach va être réinitialisée. Veuillez recharger la page.' : 'Valeur Ach mise à jour avec succès. Veuillez recharger la page.');
}

if (window.sketchup) {
    window.sketchup.ready();
    window.sketchup.saveAch = function(entityId, newValue) {
        const callbackUrl = `skp:saveAch@${encodeURIComponent(entityId)}|||${encodeURIComponent(newValue)}`;
        window.location.href = callbackUrl;
    };
}

//code JavaScript pour le bouton caché
document.getElementById('hidden_button').addEventListener('click', function() {
    console.log('Tentative de lancement du simulateur de vol');
    window.location.href = 'skp:launch_flight_simulator@';
});