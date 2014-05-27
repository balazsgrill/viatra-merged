/*******************************************************************************
 * Copyright (c) 2010-2012, Abel Hegedus, Istvan Rath and Daniel Varro
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Abel Hegedus - initial API and implementation
 *******************************************************************************/

package org.eclipse.incquery.querybasedfeatures.tooling

import com.google.inject.Inject
import java.util.ArrayList
import java.util.Map
import java.util.StringTokenizer
import org.apache.log4j.Logger
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.incquery.patternlanguage.emf.eMFPatternLanguage.ClassType
import org.eclipse.incquery.patternlanguage.emf.util.IErrorFeedback
import org.eclipse.incquery.patternlanguage.patternLanguage.Annotation
import org.eclipse.incquery.patternlanguage.patternLanguage.BoolValue
import org.eclipse.incquery.patternlanguage.patternLanguage.Pattern
import org.eclipse.incquery.patternlanguage.patternLanguage.StringValue
import org.eclipse.incquery.patternlanguage.patternLanguage.VariableValue
import org.eclipse.incquery.querybasedfeatures.runtime.QueryBasedFeatureKind
import org.eclipse.incquery.querybasedfeatures.runtime.handler.QueryBasedFeatures
import org.eclipse.incquery.tooling.core.generator.ExtensionGenerator
import org.eclipse.incquery.tooling.core.generator.fragments.IGenerationFragment
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension org.eclipse.incquery.patternlanguage.helper.CorePatternLanguageHelper.*
import java.io.IOException
import org.eclipse.incquery.tooling.core.generator.genmodel.IEiqGenmodelProvider

/* usage: @DerivedFeature(
 *      feature="featureName", (default: patten name)
 *      source="Src" (default: first parameter),
 *      target="Trg" (default: second parameter),
 *      kind="single/many/counter/sum/iteration" (default: feature.isMany?many:single)
 *      keepCache="true/false" (default: true)
 *      )
 */
/**
 * @author Abel Hegedus
 *
 */
class QueryBasedFeatureGenerator implements IGenerationFragment {

  @Inject protected IEiqGenmodelProvider provider
  @Inject protected Logger logger
  @Inject protected IErrorFeedback errorFeedback
  @Inject protected extension ExtensionGenerator exGen
  @Inject protected extension DerivedFeatureSourceCodeUtil codeGen
  
  protected static String ANNOTATION_LITERAL      = "QueryBasedFeature"
  protected static String DERIVED_EXTENSION_POINT = "org.eclipse.incquery.runtime.base.wellbehaving.derived.features"
  protected static String DERIVED_ERROR_CODE      = "org.eclipse.incquery.runtime.querybasedfeature.error"
  protected static String ECORE_ANNOTATION        = "http://www.eclipse.org/emf/2002/Ecore"
  protected static String SETTING_DELEGATES_KEY   = "settingDelegates"
  protected static String SETTING_DELEGATES_VALUE = "org.eclipse.incquery.querybasedfeature"
  protected static String DERIVED_EXTENSION_PREFIX  = "extension.derived."

  protected static Map<String,QueryBasedFeatureKind> kinds = newHashMap(
    Pair::of("single", QueryBasedFeatureKind::SINGLE_REFERENCE),
    Pair::of("many", QueryBasedFeatureKind::MANY_REFERENCE),
    Pair::of("sum", QueryBasedFeatureKind::SUM),
    Pair::of("iteration", QueryBasedFeatureKind::ITERATION)
  )
  
  private ModelCodeBasedGenerator modelCodeBasedGenerator = new ModelCodeBasedGenerator(this)
  private SettingDelegateBasedGenerator delegateBasedGenerator = new SettingDelegateBasedGenerator(this)
  
  override getAdditionalBinIncludes() {
    return newArrayList()
  }

  override getProjectDependencies() {
    return newArrayList()
  }

  override getProjectPostfix() {
    return null
  }
  
  override generateFiles(Pattern pattern, IFileSystemAccess fsa) {
    processAnnotations(pattern, true)
  }
  
  override cleanUp(Pattern pattern, IFileSystemAccess fsa) {
    processAnnotations(pattern, false)
  }
  
  def private processAnnotations(Pattern pattern, boolean generate) {
    for(annotation : pattern.getAnnotationsByName(QueryBasedFeatureGenerator::ANNOTATION_LITERAL)) {
      val useModelCode = annotation.getFirstAnnotationParameter("generateIntoModelCode")
      if(useModelCode != null && (useModelCode as BoolValue).value == true){
        modelCodeBasedGenerator.processJavaFiles(pattern, annotation, generate)
      } else {
        delegateBasedGenerator.updateAnnotations(pattern, annotation, generate)
      }
    }
  }
  
  override extensionContribution(Pattern pattern) {
    val parameterList = newArrayList()
    for(annotation : pattern.getAnnotationsByName(ANNOTATION_LITERAL)) {
      try{
        parameterList += pattern.processDerivedFeatureAnnotation(annotation, false)
      } catch(IllegalArgumentException e){
        logger.error(e.message)
      }
    }
    if(parameterList.empty){
      return newArrayList()
    }
    val wellbehaving = newArrayList(
      // create well-behaving extension using nsUri, classifier name and feature name
      contribExtension(pattern.derivedContributionId, DERIVED_EXTENSION_POINT) [
        parameterList.forEach [ parameters |
          contribElement(it, "wellbehaving-derived-feature") [
            contribAttribute(it, "package-nsUri", parameters.ePackage.nsURI)
            contribAttribute(it, "classifier-name", parameters.source.name)
            contribAttribute(it, "feature-name", parameters.feature.name)
          ]
        ]
      ]
    )
    return wellbehaving
  }
  
  override getRemovableExtensions() {
    newArrayList(
      Pair::of(DERIVED_EXTENSION_PREFIX, DERIVED_EXTENSION_POINT)
    )
  }
  
  override removeExtension(Pattern pattern) {
    newArrayList(
      Pair::of(pattern.derivedContributionId, DERIVED_EXTENSION_POINT)
    )
  }
  
  def protected derivedContributionId(Pattern pattern) {
    DERIVED_EXTENSION_PREFIX+getFullyQualifiedName(pattern)
  }
  
  def protected processDerivedFeatureAnnotation(Pattern pattern, Annotation annotation, boolean feedback){
    val parameters = new QueryBasedFeatureParameters
    parameters.pattern = pattern
    parameters.annotation = annotation
    
    var sourceTmp = ""
    var targetTmp = ""
    var featureTmp = ""
    var kindTmp = ""
    var keepCacheTmp = true

    if(pattern.parameters.size < 2){
      if(feedback)
        errorFeedback.reportError(pattern,"Pattern has less than 2 parameters!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+" has less than 2 parameters!")
    }

      for (ap : annotation.parameters) {
        if (ap.name.matches("source")) {
          sourceTmp = (ap.value as VariableValue).value.getVar
        } else if (ap.name.matches("target")) {
          targetTmp = (ap.value as VariableValue).value.getVar
        } else if (ap.name.matches("feature")) {
          featureTmp = (ap.value as StringValue).value
        } else if (ap.name.matches("kind")) {
          kindTmp = (ap.value as StringValue).value
        } else if (ap.name.matches("keepCache")) {
          keepCacheTmp = (ap.value as BoolValue).value
        }
      }

    if(featureTmp == ""){
      featureTmp = pattern.name
    }

    if(sourceTmp == ""){
      sourceTmp = pattern.parameters.get(0).name
    }
    if(!pattern.parameterPositionsByName.keySet.contains(sourceTmp)){
      if(feedback)
        errorFeedback.reportError(annotation,"No parameter for source " + sourceTmp +" !", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": No parameter for source " + sourceTmp +" !")
    }

    val sourcevar = pattern.parameters.get(pattern.parameterPositionsByName.get(sourceTmp))
    val sourceType = sourcevar.type
    if(!(sourceType instanceof ClassType) || !((sourceType as ClassType).classname instanceof EClass)){
      if(feedback)
        errorFeedback.reportError(sourcevar,"Source " + sourceTmp +" is not EClass!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": Source " + sourceTmp +" is not EClass!")
    }
    var source = (sourceType as ClassType).classname as EClass

    parameters.sourceVar = sourceTmp
    parameters.source = source

    if(source == null || source.EPackage == null){
      if(feedback)
        errorFeedback.reportError(sourcevar,"Source EClass or EPackage not found!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": Source EClass or EPackage not found!")
    }
    val pckg = source.EPackage
    if(pckg == null){
      if(feedback)
        errorFeedback.reportError(sourcevar,"EPackage not found!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": EPackage not found!")
    }
    parameters.ePackage = pckg

    val featureString = featureTmp
    val features = source.EAllStructuralFeatures.filter[it.name == featureString]
    if(features.size != 1){
      if(feedback)
        errorFeedback.reportError(annotation,"Feature " + featureTmp +" not found in class " + source.name +"!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": Feature " + featureTmp +" not found in class " + source.name +"!")
    }
    val feature = features.iterator.next
    if(!(feature.derived && feature.transient && feature.volatile)){
      if(feedback)
        errorFeedback.reportError(annotation,"Feature " + featureTmp +" must be set derived, transient, volatile, non-changeable!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": Feature " + featureTmp +" must be set derived, transient, volatile!")
    }
    parameters.feature = feature

    if(kindTmp == ""){
      if(feature.many){
        kindTmp = "many"
      } else {
        kindTmp = "single"
      }
    }

    if(!kinds.keySet.contains(kindTmp)){
      if(feedback)
        errorFeedback.reportError(annotation,"Kind not set, or not in " + kinds.keySet + "!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
      throw new IllegalArgumentException("Query-based feature pattern "+pattern.fullyQualifiedName+": Kind not set, or not in " + kinds.keySet + "!")
    }
    val kind = kinds.get(kindTmp)
    parameters.kind = kind

    if(targetTmp == ""){
      targetTmp = pattern.parameters.get(1).name
    } else {
      if(!pattern.parameterPositionsByName.keySet.contains(targetTmp)){
        if(feedback)
          errorFeedback.reportError(annotation,"Target " + targetTmp +" not set or no such parameter!", DERIVED_ERROR_CODE, Severity::ERROR, IErrorFeedback::FRAGMENT_ERROR_TYPE)
        throw new IllegalArgumentException("Derived feature pattern "+pattern.fullyQualifiedName+": Target " + targetTmp +" not set or no such parameter!")
      }
    }
    parameters.targetVar = targetTmp
    parameters.keepCache = keepCacheTmp


    return parameters
  }
}

class QueryBasedFeatureParameters{

  public Pattern pattern
  public Annotation annotation

  public String sourceVar
  public String targetVar

  public EPackage ePackage
  public EClass source
  public EClass target
  public EStructuralFeature feature
  
  public QueryBasedFeatureKind kind
  public boolean keepCache
  
}