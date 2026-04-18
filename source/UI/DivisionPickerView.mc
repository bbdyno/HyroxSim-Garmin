//
//  DivisionPickerView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Uses Connect IQ's Menu2 for a scrollable, touch+button compatible list.
// Selecting a division pushes ActiveWorkoutView with the matching HYROX preset.
class DivisionPickerView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Division" });
        var all = HyroxDivision.all();
        for (var i = 0; i < all.size(); i += 1) {
            var d = all[i] as String;
            addItem(new MenuItem(
                HyroxDivision.shortName(d),
                HyroxDivision.displayName(d),
                d,
                null
            ));
        }
    }
}

class DivisionPickerDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var division = item.getId() as String;
        var template = WorkoutTemplate.hyroxPreset(division);
        var view = new ActiveWorkoutView(template);
        var delegate = new ActiveWorkoutDelegate(view);
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
