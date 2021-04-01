//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <collections/collections_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) collections_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "CollectionsPlugin");
  collections_plugin_register_with_registrar(collections_registrar);
}
