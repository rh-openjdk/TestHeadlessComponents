import java.awt.GraphicsEnvironment;
import java.util.Arrays;

public class TestArgumentParser {

    String jreSdkHeadless = null;
    String displayValue = null;
    Enum testOptions;

    public static final String JDK_HEADLESS="jre~headless";
    public static final String JDK_JRE="jre";
    public static final String JDK_SDK="sdk";

    enum TestOptions{
        ALL,
	COMPATIBLE,
	INCOMPATIBLE;
    }

    public void parseDisplayTestArgs(String[] args) {
        if (args.length != 3) {
            System.err.println("You must provide exactly 3 arguments: -jreSdkHeadless=$OTOOL_jresdk -displayValue=$DISPLAY -test=$OPTION");
	    System.err.println("the last argument stands determines which components should be tested. If ran outside of the respective TPS");
	    System.err.println("you probably want to use all to run all tests. The other options test jre-headless compatible/incompatible components respectively");
            System.exit(69);
        }
        for (String arg : args) {
            String[] argSplit = arg.split("=");
            if (argSplit[0].equals("-jreSdkHeadless")) {
                if (argSplit.length != 2) {
                    System.err.println("Wrongly specified argument! try something like -jreSdkHeadless=$OTOOL_jresdk . The test will continue and die later.");
                }
                this.jreSdkHeadless = argSplit[1];
            } else if (argSplit[0].equals("-displayValue")) {
                if (argSplit.length != 2) {
                    if (argSplit.length == 1) {
                        System.out.println("When display is not set. This is expected and is treated as okay.");
                        this.displayValue = null;
                    } else {
                        System.err.println("Wrongly specified argument! try something like -displayValue=$DISPLAY. The test will continue and die later.");
                    }
                } else {
                    this.displayValue = argSplit[1];
                }
            } else if (argSplit[0].equals("-test")){
		switch(argSplit[1]){
 		    case "compatible":
			testOptions = TestOptions.COMPATIBLE;
			break;
 		    case "incompatible":
			testOptions = TestOptions.INCOMPATIBLE;
			break;
 		    case "all":
			testOptions = TestOptions.ALL;
			break;
		    default:
			System.err.println("Found weird argument: " + arg);
                	System.exit(69);
		}

	    } else {
                System.err.println("Found weird argument: " + arg);
                System.exit(69);
            }
        }
    }

    public boolean isGraphicsEnvironmentHeadless() {
    	return GraphicsEnvironment.isHeadless();
    }
    
    public boolean isDisplayValid() {
        return this.displayValue.equals(":0");
    }

    public boolean isDisplayInvalid() {
        return this.displayValue == null || this.displayValue.equals(":666");
    }

    public boolean isJdkHeadless() {
        return jreSdkHeadless.equals(JDK_HEADLESS);
    }

    public boolean isJdkJre() {
        return jreSdkHeadless.equals(JDK_JRE);
    }

    public boolean isJdkSdk() {
        return jreSdkHeadless.equals(JDK_SDK);
    }

    public boolean testJreHeadlessCompatible(){
        return testOptions == TestOptions.ALL || testOptions == TestOptions.COMPATIBLE;
    }

    public boolean testJreHeadlessIncompatible(){
        return testOptions == TestOptions.ALL || testOptions == TestOptions.INCOMPATIBLE;
    }


}
