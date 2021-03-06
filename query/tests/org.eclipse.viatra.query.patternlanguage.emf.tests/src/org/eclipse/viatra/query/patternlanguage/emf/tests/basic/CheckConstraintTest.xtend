/*******************************************************************************
 * Copyright (c) 2010-2012, Zoltan Ujhelyi, Istvan Rath and Daniel Varro
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Zoltan Ujhelyi - initial API and implementation
 *******************************************************************************/
package org.eclipse.viatra.query.patternlanguage.emf.tests.basic

import com.google.inject.Inject
import com.google.inject.Injector
import org.eclipse.viatra.query.patternlanguage.emf.eMFPatternLanguage.PatternModel
import org.eclipse.viatra.query.patternlanguage.emf.tests.EMFPatternLanguageInjectorProvider
import org.eclipse.viatra.query.patternlanguage.emf.validation.EMFPatternLanguageJavaValidator
import org.eclipse.viatra.query.patternlanguage.validation.IssueCodes
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtext.junit4.validation.ValidationTestHelper
import org.eclipse.xtext.junit4.validation.ValidatorTester
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Ignore

@RunWith(typeof(XtextRunner))
@InjectWith(typeof(EMFPatternLanguageInjectorProvider))
class CheckConstraintTest {

	@Inject
	ParseHelper<PatternModel> parseHelper

	@Inject
	EMFPatternLanguageJavaValidator validator

	@Inject
	Injector injector

	ValidatorTester<EMFPatternLanguageJavaValidator> tester

	@Inject extension ValidationTestHelper

	@Before
	def void initialize() {
		tester = new ValidatorTester(validator, injector)
	}

	@Test
	@Ignore("Custom white lists removed")
	def whitelistedCheck() {
		val model = parseHelper.parse('
			package org.eclipse.viatra.query.patternlanguage.emf.tests
			import "http://www.eclipse.org/emf/2002/Ecore"

			pattern name(D) = {
				EDouble(D);
				check(java::lang::Math::abs(D) > 10.5);
			}
		')
//		model.assertError(PatternLanguagePackage::Literals.PATTERN_MODEL, IssueCodes::PACKAGE_NAME_MISMATCH)
		model.assertNoErrors
		tester.validate(model).assertOK
	}

	@Test
	def nonWhitelistedCheck() {
		val model = parseHelper.parse('
			package org.eclipse.viatra.query.patternlanguage.emf.tests
			import "http://www.eclipse.org/emf/2002/Ecore"

			pattern name(L) = {
				ELong(L);
				check(^java::util::Calendar::getInstance().getTime().getTime() > L);
			}
		')
//		model.assertError(PatternLanguagePackage::Literals.PATTERN_MODEL, IssueCodes::PACKAGE_NAME_MISMATCH)
		model.assertNoErrors
		tester.validate(model).assertWarning(IssueCodes::CHECK_WITH_IMPURE_JAVA_CALLS)
	}

}