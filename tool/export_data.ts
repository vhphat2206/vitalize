/**
 * Exports the content of the React app (../fiber-gym-app) to JSON assets for the Flutter app:
 * exercises, muscles, routines, moves and their sources, the body artwork, the exercise demos
 * and the mannequin's body parts. Run from ../fiber-gym-app:
 *   npx tsx ../vitalize_flutter/tool/export_data.ts
 */
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { exercises } from '../../fiber-gym-app/src/data/exercises';
import { muscles, muscleOrder } from '../../fiber-gym-app/src/data/muscles';
import { equipmentLabel, levelLabel } from '../../fiber-gym-app/src/data/equipment';
import { routines } from '../../fiber-gym-app/src/data/routines';
import { moves } from '../../fiber-gym-app/src/data/moves';
import { bodyArtwork } from '../../fiber-gym-app/src/data/body/paths.generated';
import { sampleMeals } from '../../fiber-gym-app/src/data/sample-meals';
import { demos } from '../../fiber-gym-app/src/data/demos';
import { VIEW_PARTS, FIBRE_ANGLES } from '../../fiber-gym-app/src/components/demo/rig';

const out = join(import.meta.dirname, '..', 'assets', 'data');
const write = (name: string, data: unknown) => {
  writeFileSync(join(out, name), JSON.stringify(data));
  console.log(name, JSON.stringify(data).length);
};

write('exercises.json', exercises);
write('muscles.json', { muscles, order: muscleOrder });
write('equipment.json', { labels: equipmentLabel, levels: levelLabel });
write('routines.json', routines);
write('moves.json', moves);
write('body.json', bodyArtwork);
write('sample_meals.json', sampleMeals);
write('demos.json', demos);
// Body parts of the mannequin per view; a head that turns with the chest is marked `turns`.
write('rig_parts.json', {
  fibreAngles: FIBRE_ANGLES,
  views: Object.fromEntries(
    Object.entries(VIEW_PARTS).map(([view, bones]) => [
      view,
      Object.fromEntries(
        Object.entries(bones).map(([bone, parts]) => [
          bone,
          parts.map(({ turn, ...p }) => (turn ? { ...p, turns: true } : p)),
        ]),
      ),
    ]),
  ),
});
