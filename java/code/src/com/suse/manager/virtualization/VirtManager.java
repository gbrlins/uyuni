/**
 * Copyright (c) 2018 SUSE LLC
 *
 * This software is licensed to you under the GNU General Public License,
 * version 2 (GPLv2). There is NO WARRANTY for this software, express or
 * implied, including the implied warranties of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
 * along with this software; if not, see
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
 *
 * Red Hat trademarks are not licensed under GPLv2. No permission is
 * granted to use or replicate Red Hat trademarks that are incorporated
 * in this software or its documentation.
 */
package com.suse.manager.virtualization;

import com.google.gson.JsonElement;
import com.google.gson.reflect.TypeToken;
import com.suse.manager.webui.services.impl.SaltService;
import com.suse.manager.webui.services.impl.SystemQuery;
import com.suse.salt.netapi.calls.LocalCall;

import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Service providing utility functions to handle virtual machines.
 */
public class VirtManager {

    private static SystemQuery saltService = SaltService.INSTANCE;

    /**
     * Query virtual machine definition
     *
     * @param minionId the host minion ID
     * @param domainName the domain name to look for
     * @return the XML definition or an empty Optional
     */
    public static Optional<GuestDefinition> getGuestDefinition(String minionId, String domainName) {
        return SaltService.INSTANCE.getGuestDefinition(minionId, domainName);
    }

    /**
     * Query virtual host and domains capabilities.
     *
     * @param minionId the salt minion virtual host to ask about
     * @return the output of the salt virt.all_capabilities call in JSON
     */
    public static Optional<Map<String, JsonElement>> getCapabilities(String minionId) {
        return saltService.getCapabilities(minionId);
    }

    /**
     * Query the list of virtual networks defined on a salt minion.
     *
     * @param minionId the minion to ask about
     * @return a list of the network names
     */
    public static Map<String, JsonElement> getNetworks(String minionId) {
        return saltService.getNetworks(minionId);
    }

    /**
     * Query the list of virtual storage pools defined on a salt minion.
     *
     * @param minionId the minion to ask about
     * @return a map associating pool names with their informations as Json elements
     */
    public static Map<String, JsonElement> getPools(String minionId) {
        return SaltService.INSTANCE.getPools(minionId);
    }

    /**
     * Query the list of virtual storage volumes defined on a salt minion.
     *
     * @param minionId the minion to ask about
     * @return a map associating pool names with the list of volumes it contains mapped by their names
     */
    public static Map<String, Map<String, JsonElement>> getVolumes(String minionId) {
        return SaltService.INSTANCE.getVolumes(minionId);
    }

    /**
     * @param saltServiceIn to set for tests
     */
    public static void setSaltService(SaltService saltServiceIn) {
        saltService = saltServiceIn;
    }

    private VirtManager() {
    }
}
