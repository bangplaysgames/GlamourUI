local M = {};

M.corsair_roll_data = {
    ["Corsair's Roll"] = { lucky = 5, unlucky = 9, rolls = {10, 11, 11, 12, 20, 13, 15, 16, 8, 17, 24}, bust = 6, desc = 'Experience / Capacity Points', unit = '%' },
    ["Ninja Roll"] = { lucky = 4, unlucky = 8, rolls = {4, 6, 8, 25, 10, 12, 14, 2, 17, 20, 30}, bust = 10, desc = 'Evasion', unit = '' },
    ["Chaos Roll"] = { lucky = 4, unlucky = 8, rolls = {6.3, 7.8, 9.4, 25, 10.9, 12.5, 15.6, 3.1, 17.2, 18.8, 31.2}, bust = 10, desc = 'Attack', unit = '%' },
    ["Hunter's Roll"] = { lucky = 4, unlucky = 8, rolls = {10, 13, 15, 40, 18, 20, 25, 5, 27, 30, 50}, bust = 15, desc = 'Accuracy', unit = '' },
    ["Magus's Roll"] = { lucky = 2, unlucky = 6, rolls = {5, 20, 6, 8, 9, 3, 10, 13, 14, 15, 25}, bust = 8, desc = 'Magic Defense Bonus', unit = '' },
    ["Healer's Roll"] = { lucky = 3, unlucky = 7, rolls = {3, 4, 12, 5, 6, 7, 1, 8, 9, 10, 16}, bust = 4, desc = 'Cure Potency', unit = '%' },
    ["Drachen Roll"] = { lucky = 4, unlucky = 8, rolls = {10, 13, 15, 40, 18, 20, 25, 5, 28, 30, 50}, bust = 15, desc = 'Pet: Accuracy / Ranged Accuracy', unit = '' },
    ["Choral Roll"] = { lucky = 2, unlucky = 6, rolls = {8, 42, 11, 15, 19, 4, 23, 27, 31, 35, 50}, bust = 25, desc = 'Spell Interruption Rate Down', unit = '%' },
    ["Monk's Roll"] = { lucky = 3, unlucky = 7, rolls = {8, 10, 32, 12, 14, 16, 4, 20, 22, 24, 40}, bust = 10, desc = 'Subtle Blow', unit = '' },
    ["Beast Roll"] = { lucky = 4, unlucky = 8, rolls = {6, 8, 9, 25, 11, 13, 16, 3, 17, 19, 31}, bust = 10, desc = 'Pet: Attack / Ranged Attack', unit = '%' },
    ["Samurai Roll"] = { lucky = 2, unlucky = 6, rolls = {8, 32, 10, 12, 14, 4, 16, 20, 22, 24, 40}, bust = 10, desc = 'Store TP', unit = '' },
    ["Evoker's Roll"] = { lucky = 5, unlucky = 9, rolls = {1, 1, 1, 1, 3, 2, 2, 2, 1, 3, 4}, bust = nil, desc = 'Refresh', unit = '' },
    ["Rogue's Roll"] = { lucky = 5, unlucky = 9, rolls = {1, 2, 3, 4, 10, 5, 6, 7, 1, 8, 14}, bust = 5, desc = 'Critical Hit Rate', unit = '%' },
    ["Warlock's Roll"] = { lucky = 4, unlucky = 8, rolls = {2, 3, 4, 12, 5, 6, 7, 1, 8, 9, 15}, bust = 5, desc = 'Magic Accuracy', unit = '' },
    ["Fighter's Roll"] = { lucky = 5, unlucky = 9, rolls = {1, 2, 3, 4, 10, 5, 6, 6, 1, 7, 15}, bust = nil, desc = 'Double Attack', unit = '%' },
    ["Puppet Roll"] = { lucky = 3, unlucky = 7, rolls = {5, 8, 35, 11, 14, 18, 2, 22, 26, 30, 40}, bust = 12, desc = 'Pet: Magic Accuracy / Magic Attack Bonus', unit = '' },
    ["Gallant's Roll"] = { lucky = 3, unlucky = 7, rolls = {4.69, 5.86, 19.53, 7.03, 8.59, 10.16, 3.13, 11.72, 13.67, 15.63, 23.44}, bust = -11.72, desc = 'Defense', unit = '%' },
    ["Wizard's Roll"] = { lucky = 5, unlucky = 9, rolls = {4, 6, 8, 10, 25, 12, 14, 17, 2, 20, 30}, bust = 10, desc = 'Magic Attack Bonus', unit = '' },
    ["Dancer's Roll"] = { lucky = 3, unlucky = 7, rolls = {3, 4, 12, 5, 6, 7, 1, 8, 9, 10, 16}, bust = 4, desc = 'Regen', unit = '' },
    ["Scholar's Roll"] = { lucky = 2, unlucky = 6, rolls = {2, 10, 3, 4, 4, 1, 5, 6, 7, 7, 12}, bust = 3, desc = 'Conserve MP', unit = '%' },
    ["Bolter's Roll"] = { lucky = 3, unlucky = 9, rolls = {6, 6, 16, 8, 8, 10, 10, 12, 4, 14, 20}, bust = 0, desc = 'Movement Speed', unit = '%' },
    ["Caster's Roll"] = { lucky = 2, unlucky = 7, rolls = {6, 15, 7, 8, 9, 10, 5, 11, 12, 13, 20}, bust = 10, desc = 'Fast Cast', unit = '%' },
    ["Courser's Roll"] = { lucky = 3, unlucky = 9, rolls = {2, 3, 11, 4, 5, 6, 7, 8, 1, 10, 12}, bust = -3, desc = 'Snapshot', unit = '%' },
    ["Blitzer's Roll"] = { lucky = 4, unlucky = 9, rolls = {2, 3, 4, 11, 5, 6, 7, 8, 1, 10, 12}, bust = -3, desc = 'Haste', unit = '%' },
    ["Tactician's Roll"] = { lucky = 5, unlucky = 8, rolls = {10, 10, 10, 10, 30, 10, 10, 0, 20, 20, 40}, bust = -10, desc = 'Regain', unit = '' },
    ["Allies' Roll"] = { lucky = 3, unlucky = 10, rolls = {2, 3, 20, 5, 7, 9, 11, 13, 15, 1, 25}, bust = -5, desc = 'Skillchain Damage / Accuracy', unit = '%' },
    ["Miser's Roll"] = { lucky = 5, unlucky = 7, rolls = {30, 50, 70, 90, 200, 110, 20, 130, 150, 170, 250}, bust = 0, desc = 'Save TP', unit = '' },
    ["Companion's Roll"] = { lucky = 2, unlucky = 10, rolls = {'20TP/4HP', '50TP/20HP', '20TP/6HP', '20TP/8HP', '30TP/10HP', '30TP/12HP', '30TP/14HP', '40TP/16HP', '40TP/18HP', '10TP/3HP', '60TP/25HP'}, bust = '0TP/0HP', desc = 'Pet: Regain / Regen', unit = '' },
    ["Avenger's Roll"] = { lucky = 4, unlucky = 8, rolls = {3, 4, 5, 14, 6, 7, 8, 1, 9, 10, 16}, bust = -4, desc = 'Counter Rate', unit = '%' },
    ["Naturalist's Roll"] = { lucky = 3, unlucky = 7, rolls = {6, 7, 15, 8, 9, 10, 5, 11, 12, 13, 20}, bust = -5, desc = 'Enhancing Magic Duration', unit = '%' },
    ["Runeist's Roll"] = { lucky = 4, unlucky = 8, rolls = {4, 6, 8, 25, 10, 12, 14, 2, 17, 20, 30}, bust = 10, desc = 'Magic Evasion', unit = '' },
};

return M;

