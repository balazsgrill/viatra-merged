/*******************************************************************************
 * Copyright (c) 2010-2012, Abel Hegedus, Istvan Rath and Daniel Varro
 * All rights reserved. This prnteogram and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Abel Hegedus - initial API and implementation
 *******************************************************************************/
package org.eclipse.viatra.transformation.evm.update;

/**
 * This interface is used for listening to update complete events sent by an {@link IUpdateCompleteProvider}.
 * 
 * @author Abel Hegedus
 * 
 */
public interface IUpdateCompleteListener {

    /**
     * This method is called when an update complete event occurs.
     */
    void updateComplete();

}
