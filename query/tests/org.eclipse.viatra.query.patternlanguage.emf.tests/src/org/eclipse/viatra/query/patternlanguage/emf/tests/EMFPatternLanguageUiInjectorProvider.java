/*
* generated by Xtext
*/
package org.eclipse.viatra.query.patternlanguage.emf.tests;

import org.apache.log4j.Logger;
import org.eclipse.viatra.query.patternlanguage.emf.EMFPatternLanguagePlugin;
import org.eclipse.viatra.query.patternlanguage.emf.ui.internal.EMFPatternLanguageActivator;
import org.eclipse.viatra.query.runtime.util.IncQueryLoggingUtil;
import org.eclipse.xtext.junit4.IInjectorProvider;

import com.google.inject.Injector;

public class EMFPatternLanguageUiInjectorProvider implements IInjectorProvider {

	public Injector getInjector() {
		Injector injector = EMFPatternLanguageActivator.getInstance().getInjector("org.eclipse.viatra.query.patternlanguage.emf.EMFPatternLanguage");
	    IncQueryLoggingUtil.setExternalLogger(injector.getInstance(Logger.class));
	    EMFPatternLanguagePlugin.getInstance().addCompoundInjector(injector, EMFPatternLanguagePlugin.TEST_INJECTOR_PRIORITY);
        return injector;
	}

}
