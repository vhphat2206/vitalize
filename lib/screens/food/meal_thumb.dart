import 'package:flutter/widgets.dart';

import '../../app/theme.dart';
import '../../logic/meal_photo.dart';
import '../../state/log_store.dart';

/// A meal's saved photo, cropped square, on the bg-3 tone (the tone alone when there's no photo).
class MealThumb extends StatelessWidget {
  const MealThumb({super.key, required this.meal, required this.size, required this.radius});

  final LoggedMeal meal;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = mealPhotoImage(meal);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: V.bg3,
        child: image == null
            ? null
            : Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
      ),
    );
  }
}
